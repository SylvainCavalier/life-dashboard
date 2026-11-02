require "test_helper"

class AlfredSmsAvailabilityTest < ActiveSupport::TestCase
  setup { travel_to Time.zone.local(2026, 11, 2, 9, 0) }
  teardown { travel_back }

  def days(from, to)
    Alfred::Sms::Availability.new(from, to).call[:days]
  end

  test "donne les creneaux sans jamais le contenu des evenements" do
    Event.create!(title: "Rendez-vous oncologue", location: "Hopital secret", description: "Resultats",
                  start_time: Time.zone.local(2026, 11, 3, 14, 0), end_time: Time.zone.local(2026, 11, 3, 15, 30))

    result = Alfred::Sms::Availability.new("2026-11-03", "2026-11-03").call
    day = result[:days].first

    assert_equal "mardi", day[:weekday]
    assert_equal [{ start: "14:00", end: "15:30" }], day[:busy]
    assert_equal [{ start: "08:00", end: "14:00" }, { start: "15:30", end: "21:00" }], day[:free]
    assert_no_match(/oncologue|Hopital|Resultats/, result.to_json)
  end

  test "un evenement sans fin dure une heure et un jour libre est entierement libre" do
    Event.create!(title: "Cafe", start_time: Time.zone.local(2026, 11, 3, 10, 0))

    tuesday, wednesday = days("2026-11-03", "2026-11-04")

    assert_equal [{ start: "10:00", end: "11:00" }], tuesday[:busy]
    assert_equal [{ start: "08:00", end: "21:00" }], wednesday[:free]
  end

  test "les echeances n'occupent pas Sylvain, une journee entiere est signalee" do
    Event.create!(title: "URSSAF", event_type: "echeance", all_day: true, start_time: Time.zone.local(2026, 11, 3))
    assert_not days("2026-11-03", "2026-11-03").first[:all_day_event]

    Event.create!(title: "Conge", all_day: true, start_time: Time.zone.local(2026, 11, 4), end_time: Time.zone.local(2026, 11, 5))
    wednesday, thursday, friday = days("2026-11-04", "2026-11-06")
    assert wednesday[:all_day_event]
    assert thursday[:all_day_event]
    assert_not friday[:all_day_event]
  end

  test "aujourd'hui, seul ce qui reste de la journee est libre" do
    assert_equal "09:00", days("2026-11-02", "2026-11-02").first[:free].first[:start]
  end

  test "refuse les periodes passees, trop longues ou trop lointaines" do
    assert_raises(ArgumentError) { days("2026-10-01", "2026-10-02") }
    assert_raises(ArgumentError) { days("2026-11-03", "2026-12-30") }
    assert_raises(ArgumentError) { days("2028-01-01", "2028-01-02") }
    assert_raises(ArgumentError) { days("demain", "2026-11-03") }
  end
end
