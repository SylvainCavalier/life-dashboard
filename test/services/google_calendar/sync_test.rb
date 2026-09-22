require "test_helper"
require "minitest/mock"

class GoogleCalendar::SyncTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Double du client : un agenda en memoire, qui journalise les ecritures.
  class FakeClient
    attr_reader :events, :calls

    def initialize(events = [])
      @events = events
      @calls = []
      @counter = 0
    end

    def each_event(**, &)
      @events.each(&)
    end

    def insert(google_event)
      @calls << [:insert, google_event.summary]
      google_event.id = "new-#{@counter += 1}"
      google_event.updated = DateTime.parse("2026-09-22T12:00:00Z")
      google_event
    end

    def update(google_id, google_event)
      @calls << [:update, google_id]
      raise GoogleCalendar::Client::NotFound, "introuvable" if google_id == "gone"

      google_event.id = google_id
      google_event.updated = DateTime.parse("2026-09-22T12:00:00Z")
      google_event
    end

    def delete(google_id)
      @calls << [:delete, google_id]
      raise GoogleCalendar::Client::NotFound, "introuvable" if google_id == "gone"
    end
  end

  def google_event(id:, summary:, start_iso:, updated: "2026-09-20T10:00:00Z", **attrs)
    Google::Apis::CalendarV3::Event.new(
      id: id, summary: summary, updated: DateTime.parse(updated),
      start: Google::Apis::CalendarV3::EventDateTime.new(date_time: DateTime.parse(start_iso)),
      end: Google::Apis::CalendarV3::EventDateTime.new(date_time: DateTime.parse(start_iso) + Rational(1, 24)),
      **attrs
    )
  end

  def sync_with(*events)
    client = FakeClient.new(events)
    [GoogleCalendar::Sync.new(client: client, logger: Logger.new(nil)), client]
  end

  setup do
    travel_to Time.zone.local(2026, 9, 22, 12, 0)
  end

  test "un evenement Google inconnu est cree localement, sans repartir vers Google" do
    sync, client = sync_with(google_event(id: "g1", summary: "Dentiste", start_iso: "2026-09-25T08:00:00Z"))

    report = nil
    GoogleCalendar.stub(:enabled?, true) do
      assert_no_enqueued_jobs(only: GoogleCalendarPushJob) { report = sync.pull! }
    end

    event = Event.find_by!(google_event_id: "g1")
    assert_equal "Dentiste", event.title
    assert_equal "autre", event.event_type
    assert_equal Time.zone.local(2026, 9, 25, 10, 0), event.start_time
    assert_equal 1, report.pulled
    assert_empty client.calls
  end

  test "Google fait foi : une version plus recente ecrase la locale, une version connue ne touche a rien" do
    event = create(:event, title: "Ancien titre", event_type: "lecon", google_event_id: "g1",
                           google_updated_at: Time.utc(2026, 9, 20, 10))
    newer = google_event(id: "g1", summary: "Nouveau titre", start_iso: "2026-09-25T08:00:00Z",
                         updated: "2026-09-21T10:00:00Z")
    same = google_event(id: "g1", summary: "Ignore", start_iso: "2026-09-25T08:00:00Z", updated: "2026-09-20T10:00:00Z")

    sync_with(newer).first.pull!
    assert_equal "Nouveau titre", event.reload.title
    assert_equal "lecon", event.event_type, "le classement local survit a une mise a jour Google"
    assert_equal Time.utc(2026, 9, 21, 10), event.google_updated_at

    sync_with(same).first.pull!
    assert_equal "Nouveau titre", event.reload.title
  end

  test "un evenement lie que Google ne renvoie plus dans la fenetre est supprime, pas ceux hors fenetre" do
    in_window = create(:event, google_event_id: "gone-1", start_time: Time.zone.local(2026, 10, 1, 9), end_time: nil)
    old = create(:event, google_event_id: "old", start_time: Time.zone.local(2025, 1, 1, 9), end_time: nil)
    local_only = create(:event, google_event_id: nil, start_time: Time.zone.local(2026, 10, 1, 9), end_time: nil)
    sync, client = sync_with(google_event(id: "g2", summary: "Reste", start_iso: "2026-10-02T08:00:00Z"))

    report = sync.pull!

    assert_nil Event.find_by(id: in_window.id)
    assert Event.exists?(old.id)
    assert Event.exists?(local_only.id)
    assert_equal 1, report.deleted
    assert_not_includes client.calls.map(&:first), :delete, "une suppression venue de Google ne repart pas vers Google"
  end

  test "les evenements locaux jamais pousses partent vers Google et recoivent leur identifiant" do
    event = create(:event, title: "Cours", google_event_id: nil)
    sync, client = sync_with

    report = sync.pull!

    assert_equal [[:insert, "Cours"]], client.calls
    assert_equal "new-1", event.reload.google_event_id
    assert_equal Time.utc(2026, 9, 22, 12), event.google_updated_at
    assert_equal 1, report.pushed
  end

  test "push! met a jour un evenement lie et recree un evenement disparu chez Google" do
    linked = create(:event, google_event_id: "g1")
    vanished = create(:event, google_event_id: "gone", title: "Reapparait")
    sync, client = sync_with

    sync.push!(linked)
    sync.push!(vanished)

    assert_equal [[:update, "g1"], [:update, "gone"], [:insert, "Reapparait"]], client.calls
    assert_equal "new-1", vanished.reload.google_event_id
  end

  test "delete! ignore un evenement deja disparu" do
    sync, client = sync_with

    assert_nothing_raised { sync.delete!("gone") }
    assert_equal [[:delete, "gone"]], client.calls
  end

  test "un evenement Google invalide est signale sans interrompre le passage" do
    bad = google_event(id: "bad", summary: "Sans date", start_iso: "2026-09-25T08:00:00Z")
    bad.start = nil
    bad.end = nil
    sync, = sync_with(bad, google_event(id: "ok", summary: "Valide", start_iso: "2026-09-25T08:00:00Z"))

    report = sync.pull!

    assert_equal 1, report.pulled
    assert_equal 1, report.errors.size
    assert Event.exists?(google_event_id: "ok")
  end
end
