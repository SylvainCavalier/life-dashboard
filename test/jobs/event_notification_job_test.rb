require "test_helper"
require "minitest/mock"

class EventNotificationJobTest < ActiveJob::TestCase
  setup do
    @sent = []
    PushNotifications.transport = ->(_subscription, message) { @sent << JSON.parse(message) }
    create(:push_subscription)
    @start = Time.zone.local(2026, 11, 12, 14, 30)
  end

  teardown { PushNotifications.transport = nil }

  def notify(at)
    PushNotifications.stub(:configured?, true) { EventNotificationJob.perform_now(at) }
  end

  test "previent une heure avant, une seule fois" do
    event = create(:event, title: "Dentiste", start_time: @start, end_time: @start + 1.hour, location: "Créteil")

    notify(@start - 61.minutes)
    assert_empty @sent

    notify(@start - 60.minutes)
    assert_equal 1, @sent.size
    assert_equal "Dentiste", @sent.first["title"]
    assert_equal "Dans 1 h, à 14:30 · Créteil", @sent.first["body"]
    assert_equal "/agenda", @sent.first["url"]
    assert_not_nil event.reload.notified_at

    notify(@start - 59.minutes)
    assert_equal 1, @sent.size
  end

  test "respecte reminder_minutes et 0 = aucune notification" do
    create(:event, start_time: @start, end_time: nil, reminder_minutes: 15)
    create(:event, start_time: @start, end_time: nil, reminder_minutes: 0)

    notify(@start - 30.minutes)
    assert_empty @sent

    notify(@start - 15.minutes)
    assert_equal 1, @sent.size
    assert_equal "Dans 15 min, à 14:30", @sent.first["body"]
  end

  test "ignore les journees entieres, les echeances et ce qui a commence" do
    create(:event, all_day: true, start_time: @start.beginning_of_day + 1.day, end_time: nil, reminder_minutes: 1440)
    create(:event, event_type: "echeance", start_time: @start, end_time: nil)
    create(:event, start_time: @start - 5.minutes, end_time: nil)

    notify(@start - 10.minutes)
    assert_empty @sent
  end

  test "deplacer le rendez-vous rearme la notification" do
    event = create(:event, start_time: @start, end_time: nil)
    notify(@start - 1.hour)
    assert_equal 1, @sent.size

    later = @start + 2.hours
    event.update!(start_time: later)
    assert_nil event.notified_at

    event.update!(title: "Autre titre")
    notify(later - 1.hour)
    assert_equal 2, @sent.size
  end

  test "sans cles VAPID, rien n'est marque" do
    event = create(:event, start_time: @start, end_time: nil)
    PushNotifications.stub(:configured?, false) { EventNotificationJob.perform_now(@start - 1.hour) }
    assert_nil event.reload.notified_at
  end
end
