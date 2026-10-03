require "test_helper"

class RemindersTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  test "creation, heure saisie sans fuseau = heure de Paris" do
    post api_reminders_path, params: { reminder: { title: "Relancer le plombier", remind_at: "2030-01-15T09:30", recurrence: "weekly" } }.to_json,
                             headers: JSON_HEADERS
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal Time.zone.parse("2030-01-15 09:30"), Time.zone.parse(json["remind_at"])
    assert_equal "Toutes les semaines", json["recurrence_label"]
    assert json["recurring"]
  end

  test "creation refusee dans le passe" do
    post api_reminders_path, params: { reminder: { title: "Trop tard", remind_at: "2020-01-01T09:00" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "index : en cours, puis termines sauf status=active" do
    active = create(:reminder)
    done = create(:reminder, title: "Fait")
    done.update_columns(completed_at: Time.current)

    get api_reminders_path, headers: JSON_HEADERS
    assert_equal [active.id, done.id], JSON.parse(response.body).map { |r| r["id"] }

    get api_reminders_path(status: "active"), headers: JSON_HEADERS
    assert_equal [active.id], JSON.parse(response.body).map { |r| r["id"] }
  end

  test "vu, reporte, fait" do
    reminder = create(:reminder, remind_at: 5.minutes.from_now)
    travel 10.minutes do
      post seen_api_reminder_path(reminder), headers: JSON_HEADERS
      assert JSON.parse(response.body)["acknowledged_at"].present?

      post snooze_api_reminder_path(reminder), params: { minutes: 60 }.to_json, headers: JSON_HEADERS
      json = JSON.parse(response.body)
      assert_nil json["acknowledged_at"]
      assert_in_delta 60.minutes.from_now, Time.zone.parse(json["remind_at"]), 2

      post snooze_api_reminder_path(reminder), params: { minutes: 0 }.to_json, headers: JSON_HEADERS
      assert_response :unprocessable_entity

      post done_api_reminder_path(reminder), headers: JSON_HEADERS
      assert JSON.parse(response.body)["completed_at"].present?
    end
  end

  test "abonnement push idempotent par endpoint, puis desabonnement" do
    subscription = { endpoint: "https://web.push.apple.com/abc", keys: { p256dh: "cle", auth: "secret" } }
    2.times do
      post api_push_subscriptions_path, params: { subscription: subscription }.to_json,
                                        headers: JSON_HEADERS.merge("User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0) Safari/604.1")
      assert_response :created
    end
    assert_equal 1, PushSubscription.count

    get api_push_subscriptions_path, headers: JSON_HEADERS
    json = JSON.parse(response.body)
    assert_equal "iPhone · Safari", json["subscriptions"].first["device"]
    assert_equal false, json["configured"]

    delete api_push_subscription_path(PushSubscription.first), headers: JSON_HEADERS
    assert_equal 0, PushSubscription.count
  end

  test "notification de test refusee sans cles VAPID" do
    post test_notification_api_push_subscriptions_path, headers: JSON_HEADERS
    assert_response :service_unavailable
  end
end
