require "test_helper"

class GoogleCalendar::EventMapperTest < ActiveSupport::TestCase
  Mapper = GoogleCalendar::EventMapper

  def google_event(**attrs)
    Google::Apis::CalendarV3::Event.new(id: "g1", updated: DateTime.parse("2026-09-20T10:00:00Z"), **attrs)
  end

  def timed(start_iso, end_iso)
    { start: Google::Apis::CalendarV3::EventDateTime.new(date_time: DateTime.parse(start_iso)),
      end: Google::Apis::CalendarV3::EventDateTime.new(date_time: DateTime.parse(end_iso)) }
  end

  test "un evenement horaire garde son heure de Paris et son type dans une propriete privee" do
    event = build(:event, id: 42, title: "Dentiste", event_type: "rdv", description: "", location: nil,
                          start_time: Time.zone.local(2026, 9, 22, 9, 0), end_time: Time.zone.local(2026, 9, 22, 9, 30))

    google = Mapper.to_google(event)

    assert_equal "Dentiste", google.summary
    assert_nil google.description
    assert_nil google.location
    assert_equal "2026-09-22T09:00:00+02:00", google.start.date_time.iso8601
    assert_equal "2026-09-22T09:30:00+02:00", google.end.date_time.iso8601
    assert_equal "Europe/Paris", google.start.time_zone
    # Ce qui part sur le fil : un TimeWithZone serait serialise "2026-09-22 09:00:00 +0200" (400 chez Google)
    assert_match(/"dateTime":"2026-09-22T09:00:00(\.000)?\+02:00"/, google.to_json)
    assert_equal({ "life_dashboard_event_type" => "rdv", "life_dashboard_id" => "42" },
                 google.extended_properties.private)
  end

  test "sans fin locale, Google recoit une heure par defaut" do
    event = build(:event, start_time: Time.zone.local(2026, 9, 22, 9, 0), end_time: nil)

    google = Mapper.to_google(event)

    assert_equal "2026-09-22T10:00:00+02:00", google.end.date_time.iso8601
  end

  test "une journee entiere devient une date, la fin Google etant exclusive" do
    single = build(:event, all_day: true, start_time: Time.zone.local(2026, 9, 22), end_time: nil)
    multi = build(:event, all_day: true, start_time: Time.zone.local(2026, 9, 22),
                          end_time: Time.zone.local(2026, 9, 24))

    assert_equal [Date.new(2026, 9, 22), Date.new(2026, 9, 23)],
                 [Mapper.to_google(single).start.date, Mapper.to_google(single).end.date]
    assert_equal [Date.new(2026, 9, 22), Date.new(2026, 9, 25)],
                 [Mapper.to_google(multi).start.date, Mapper.to_google(multi).end.date]
  end

  test "un evenement Google horaire donne des attributs locaux en heure de Paris" do
    attrs = Mapper.attributes_from(google_event(summary: "Reunion", location: "Salle B", description: "ODJ",
                                                **timed("2026-09-22T07:00:00Z", "2026-09-22T08:00:00Z")))

    assert_equal "Reunion", attrs[:title]
    assert_equal "Salle B", attrs[:location]
    assert_equal false, attrs[:all_day]
    assert_equal Time.zone.local(2026, 9, 22, 9, 0), attrs[:start_time]
    assert_equal Time.zone.local(2026, 9, 22, 10, 0), attrs[:end_time]
    assert_equal "g1", attrs[:google_event_id]
    assert_equal Time.utc(2026, 9, 20, 10), attrs[:google_updated_at]
    assert_not attrs.key?(:event_type), "sans propriete privee, le type local n'est pas touche"
  end

  test "une journee entiere Google devient minuit Paris, fin inclusive" do
    attrs = Mapper.attributes_from(google_event(
                                     summary: "Salon",
                                     start: Google::Apis::CalendarV3::EventDateTime.new(date: Date.new(2026, 10, 1)),
                                     end: Google::Apis::CalendarV3::EventDateTime.new(date: Date.new(2026, 10, 3))
                                   ))

    assert attrs[:all_day]
    assert_equal Time.zone.local(2026, 10, 1), attrs[:start_time]
    assert_equal Time.zone.local(2026, 10, 2), attrs[:end_time]

    one_day = Mapper.attributes_from(google_event(
                                       start: Google::Apis::CalendarV3::EventDateTime.new(date: Date.new(2026, 10, 1)),
                                       end: Google::Apis::CalendarV3::EventDateTime.new(date: Date.new(2026, 10, 2))
                                     ))
    assert_nil one_day[:end_time]
  end

  test "une fin Google qui ne suit pas le debut, un titre vide : valeurs sures pour le modele" do
    attrs = Mapper.attributes_from(google_event(summary: nil, **timed("2026-09-22T07:00:00Z", "2026-09-22T07:00:00Z")))

    assert_equal "(Sans titre)", attrs[:title]
    assert_nil attrs[:end_time]
  end

  def typed(type)
    Google::Apis::CalendarV3::Event::ExtendedProperties.new(private: { "life_dashboard_event_type" => type })
  end

  test "le type connu de Google est repris, un type inconnu est ignore" do
    known = google_event(extended_properties: typed("lecon"), **timed("2026-09-22T07:00:00Z", "2026-09-22T08:00:00Z"))
    unknown = google_event(extended_properties: typed("pirate"),
                           **timed("2026-09-22T07:00:00Z", "2026-09-22T08:00:00Z"))

    assert_equal "lecon", Mapper.attributes_from(known)[:event_type]
    assert_equal Event::EVENT_TYPE_COLORS["lecon"], Mapper.attributes_from(known)[:color]
    assert_not Mapper.attributes_from(unknown).key?(:event_type)
  end

  test "un evenement ne dans Google est une visio s'il a un lien Meet, autre sinon" do
    meet = google_event(hangout_link: "https://meet.google.com/abc",
                        **timed("2026-09-22T07:00:00Z", "2026-09-22T08:00:00Z"))

    assert_equal "visio", Mapper.default_event_type(meet)
    assert_equal "https://meet.google.com/abc", Mapper.attributes_from(meet)[:location], "le lien sert de lieu"
    assert_equal "autre",
                 Mapper.default_event_type(google_event(**timed("2026-09-22T07:00:00Z", "2026-09-22T08:00:00Z")))
  end
end
