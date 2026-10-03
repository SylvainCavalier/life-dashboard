require "test_helper"
require "minitest/mock"

class ReminderDispatchJobTest < ActiveJob::TestCase
  setup do
    @sent = []
    PushNotifications.transport = ->(subscription, message) { @sent << [subscription.id, JSON.parse(message)] }
    @mails = []
  end

  teardown { PushNotifications.transport = nil }

  def dispatch(at)
    PushNotifications.stub(:configured?, true) do
      Reminders::EmailFallback.stub(:deliver, ->(reminder) { @mails << reminder.id; true }) do
        ReminderDispatchJob.perform_now(at)
      end
    end
  end

  test "notifie chaque appareil, relance deux fois puis envoie un mail" do
    create(:push_subscription)
    create(:push_subscription, user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Safari/605.1.15")
    reminder = create(:reminder, remind_at: 5.minutes.from_now)
    start = reminder.remind_at

    dispatch(start - 1.minute)
    assert_empty @sent

    dispatch(start)
    assert_equal 2, @sent.size
    payload = @sent.first.last
    assert_equal "Appeler le notaire", payload["title"]
    assert_equal "/reminders?open=#{reminder.id}", payload["url"]
    assert_equal false, payload["renotify"]

    dispatch(start + 5.minutes)
    assert_equal 2, @sent.size, "pas de relance avant l'intervalle"

    dispatch(start + 10.minutes)
    dispatch(start + 20.minutes)
    assert_equal 6, @sent.size
    assert @sent.last.last["renotify"]
    assert_empty @mails

    dispatch(start + 30.minutes)
    assert_equal [reminder.id], @mails
    dispatch(start + 60.minutes)
    assert_equal [reminder.id], @mails, "un seul mail par occurrence"
  end

  test "sans appareil abonne, le mail part aussitot" do
    reminder = create(:reminder, remind_at: 5.minutes.from_now)
    dispatch(reminder.remind_at + 1.minute)
    assert_equal [reminder.id], @mails
  end

  test "une notification vue n'est plus relancee" do
    create(:push_subscription)
    reminder = create(:reminder, remind_at: 5.minutes.from_now)
    start = reminder.remind_at

    dispatch(start)
    travel_to(start + 2.minutes) { reminder.reload.acknowledge! }
    dispatch(start + 15.minutes)
    dispatch(start + 45.minutes)
    assert_equal 1, @sent.size
    assert_empty @mails
  end

  test "un abonnement expire est supprime" do
    gone = create(:push_subscription)
    response = Struct.new(:code, :body).new("410", "")
    PushNotifications.transport = ->(_, _) { raise WebPush::ExpiredSubscription.new(response, "web.push.apple.com") }
    reminder = create(:reminder, remind_at: 5.minutes.from_now)

    dispatch(reminder.remind_at)
    assert_not PushSubscription.exists?(gone.id)
    assert_equal [reminder.id], @mails, "personne n'a ete atteint : mail de secours"
  end

  test "les rappels termines ou futurs ne partent pas" do
    create(:push_subscription)
    create(:reminder, remind_at: 2.hours.from_now)
    done = create(:reminder, remind_at: 5.minutes.from_now)
    done.update_columns(completed_at: Time.current)

    dispatch(1.hour.from_now)
    assert_empty @sent
  end
end
