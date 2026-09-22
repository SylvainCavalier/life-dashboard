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
class Event < ApplicationRecord
  EVENT_TYPES = %w[rdv visio lecon reunion autre].freeze

  EVENT_TYPE_LABELS = {
    "rdv" => "Rendez-vous",
    "visio" => "Visioconférence",
    "lecon" => "Leçon",
    "reunion" => "Réunion",
    "autre" => "Autre"
  }.freeze

  EVENT_TYPE_COLORS = {
    "rdv" => "#6366f1",
    "visio" => "#8b5cf6",
    "lecon" => "#06b6d4",
    "reunion" => "#f59e0b",
    "autre" => "#64748b"
  }.freeze

  # Synchronisation Google Calendar (voir GoogleCalendar). Un enregistrement
  # lie porte `google_event_id` ; `google_updated_at` est l'horodatage Google de
  # la derniere version connue, c'est lui qui dit si Google a change depuis.
  # Pour une journee entiere, `start_time` est minuit heure de Paris et
  # `end_time`, s'il existe, le minuit du dernier jour (inclusif).
  GOOGLE_SYNC_COLUMNS = %w[google_event_id google_updated_at].freeze

  after_commit :enqueue_google_push, on: [:create, :update]
  after_commit :enqueue_google_delete, on: :destroy

  # Les ecritures venues de Google (pull) ne doivent pas repartir vers Google.
  thread_mattr_accessor :google_push_suspended

  validates :title, presence: true
  validates :start_time, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validate :end_time_after_start_time, if: -> { end_time.present? }

  scope :ordered, -> { order(start_time: :asc) }
  scope :upcoming, -> { where("start_time >= ?", Time.current).ordered }
  scope :within_24h, -> { where(start_time: Time.current..24.hours.from_now).ordered }
  scope :within_1h, -> { where(start_time: Time.current..1.hour.from_now).ordered }

  def self.without_google_push
    previous = google_push_suspended
    self.google_push_suspended = true
    yield
  ensure
    self.google_push_suspended = previous
  end

  def google_synced?
    google_event_id.present?
  end

  private

  def google_push_wanted?
    GoogleCalendar.enabled? && !self.class.google_push_suspended
  end

  def enqueue_google_push
    return unless google_push_wanted?
    # Memoriser l'identifiant Google apres un push n'a rien a repousser.
    return if previous_changes.keys.all? { |column| GOOGLE_SYNC_COLUMNS.include?(column) || column == "updated_at" }

    GoogleCalendarPushJob.perform_later("upsert", id)
  end

  def enqueue_google_delete
    return unless google_push_wanted? && google_event_id.present?

    GoogleCalendarPushJob.perform_later("delete", google_event_id)
  end

  def end_time_after_start_time
    if end_time <= start_time
      errors.add(:end_time, "doit être après l'heure de début")
    end
  end
end
