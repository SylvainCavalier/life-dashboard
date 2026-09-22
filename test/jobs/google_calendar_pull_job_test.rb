require "test_helper"
require "minitest/mock"

class GoogleCalendarPullJobTest < ActiveJob::TestCase
  Report = GoogleCalendar::Sync::Report

  class FakeSync
    def initialize(report: nil, error: nil)
      @report = report
      @error = error
    end

    def pull!
      raise @error if @error

      @report
    end
  end

  def with_sync(fake, &block)
    GoogleCalendar.stub(:enabled?, true) do
      GoogleCalendar::Sync.stub(:new, fake, &block)
    end
  end

  test "sans configuration, le job ne fait rien" do
    GoogleCalendar.stub(:enabled?, false) do
      GoogleCalendar::Sync.stub(:new, ->(*) { raise "ne doit pas etre instancie" }) do
        GoogleCalendarPullJob.perform_now
      end
    end
    assert_equal "idle", CalendarSync.current.status
  end

  test "un passage reussi est consigne avec ses compteurs" do
    report = Report.new(pulled: 3, pushed: 1, deleted: 2, errors: [])

    with_sync(FakeSync.new(report: report)) { GoogleCalendarPullJob.perform_now }

    state = CalendarSync.current
    assert_equal "done", state.status
    assert_equal [3, 1, 2], [state.pulled_count, state.pushed_count, state.deleted_count]
    assert_not_nil state.last_synced_at
    assert_nil state.last_error
  end

  test "les avertissements d'un passage reussi sont conserves" do
    report = Report.new(pulled: 0, pushed: 0, deleted: 0, errors: ["Truc : titre manquant"])

    with_sync(FakeSync.new(report: report)) { GoogleCalendarPullJob.perform_now }

    assert_equal "done", CalendarSync.current.status
    assert_equal "Truc : titre manquant", CalendarSync.current.last_error
  end

  test "un echec est consigne sans lever" do
    with_sync(FakeSync.new(error: GoogleCalendar::Client::Error.new("acces refuse"))) do
      assert_nothing_raised { GoogleCalendarPullJob.perform_now }
    end

    assert_equal "failed", CalendarSync.current.status
    assert_equal "acces refuse", CalendarSync.current.last_error
  end

  test "une synchronisation deja en cours n'est pas doublee, une synchronisation abandonnee est reprise" do
    CalendarSync.current.update!(status: "running", started_at: 1.minute.ago)
    with_sync(FakeSync.new(error: RuntimeError.new("ne doit pas tourner"))) { GoogleCalendarPullJob.perform_now }
    assert_equal "running", CalendarSync.current.status

    CalendarSync.current.update!(started_at: 1.hour.ago)
    report = Report.new(pulled: 0, pushed: 0, deleted: 0, errors: [])
    with_sync(FakeSync.new(report: report)) { GoogleCalendarPullJob.perform_now }
    assert_equal "done", CalendarSync.current.status
  end

  test "run! enfile un job et passe en attente, sans doubler" do
    GoogleCalendar.stub(:enabled?, true) do
      assert_enqueued_with(job: GoogleCalendarPullJob) { CalendarSync.run! }
      assert_equal "queued", CalendarSync.current.status
      assert_no_enqueued_jobs(only: GoogleCalendarPullJob) { CalendarSync.run! }
    end
  end
end
