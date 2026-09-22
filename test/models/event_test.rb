# == Schema Information
#
# Table name: events
#
#  id                :bigint           not null, primary key
#  all_day           :boolean          default(FALSE)
#  color             :string           default("#6366f1")
#  description       :text
#  end_time          :datetime
#  event_type        :string           default("autre"), not null
#  google_updated_at :datetime
#  location          :string
#  reminder_minutes  :integer          default(60)
#  start_time        :datetime         not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  google_event_id   :string
#
# Indexes
#
#  index_events_on_event_type       (event_type)
#  index_events_on_google_event_id  (google_event_id) UNIQUE
#  index_events_on_start_time       (start_time)
#
require "test_helper"
require "minitest/mock"

class EventTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "une heure saisie sans fuseau est une heure de Paris" do
    event = Event.create!(title: "Dentiste", start_time: "2026-09-22T09:00")

    assert_equal "Europe/Paris", Time.zone.name
    assert_equal Time.utc(2026, 9, 22, 7, 0), event.start_time.utc
    assert_equal "2026-09-22T09:00:00.000+02:00", event.as_json["start_time"]
  end

  test "sans configuration Google, aucune ecriture n'enfile de push" do
    GoogleCalendar.stub(:enabled?, false) do
      assert_no_enqueued_jobs(only: GoogleCalendarPushJob) do
        event = create(:event)
        event.update!(title: "Autre")
        event.destroy!
      end
    end
  end

  test "avec Google configure, creation, modification et suppression sont poussees" do
    GoogleCalendar.stub(:enabled?, true) do
      event = nil
      assert_enqueued_with(job: GoogleCalendarPushJob) { event = create(:event) }
      assert_enqueued_with(job: GoogleCalendarPushJob, args: ["upsert", event.id]) { event.update!(title: "Modifie") }

      assert_no_enqueued_jobs(only: GoogleCalendarPushJob) { event.destroy! }
      linked = create(:event, google_event_id: "g1")
      assert_enqueued_with(job: GoogleCalendarPushJob, args: ["delete", "g1"]) { linked.destroy! }
    end
  end

  test "memoriser l'identifiant Google ou ecrire sous without_google_push ne pousse rien" do
    GoogleCalendar.stub(:enabled?, true) do
      event = Event.without_google_push { create(:event) }
      assert_no_enqueued_jobs(only: GoogleCalendarPushJob) do
        event.update!(google_event_id: "g1", google_updated_at: Time.current)
        Event.without_google_push { event.update!(title: "Depuis Google") }
      end
      assert_nil Event.google_push_suspended, "le drapeau est retabli apres le bloc"
    end
  end

  test "la fin doit suivre le debut" do
    event = build(:event, start_time: Time.zone.local(2026, 9, 22, 10), end_time: Time.zone.local(2026, 9, 22, 9))
    assert_not event.valid?
  end
end
