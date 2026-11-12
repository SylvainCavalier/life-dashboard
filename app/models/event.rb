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
#  notified_at       :datetime
#  reminder_minutes  :integer          default(60)
#  start_time        :datetime         not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  deadline_id       :bigint
#  google_event_id   :string
#
# Indexes
#
#  index_events_on_deadline_id      (deadline_id)
#  index_events_on_event_type       (event_type)
#  index_events_on_google_event_id  (google_event_id) UNIQUE
#  index_events_on_start_time       (start_time)
#
# Foreign Keys
#
#  fk_rails_...  (deadline_id => deadlines.id) ON DELETE => nullify
#
class Event < ApplicationRecord
  EVENT_TYPES = %w[rdv visio lecon reunion echeance autre].freeze

  EVENT_TYPE_LABELS = {
    "rdv" => "Rendez-vous",
    "visio" => "Visioconférence",
    "lecon" => "Leçon",
    "reunion" => "Réunion",
    "echeance" => "Échéance",
    "autre" => "Autre"
  }.freeze

  EVENT_TYPE_COLORS = {
    "rdv" => "#6366f1",
    "visio" => "#8b5cf6",
    "lecon" => "#06b6d4",
    "reunion" => "#f59e0b",
    "echeance" => "#e11d48",
    "autre" => "#64748b"
  }.freeze

  # Synchronisation Google Calendar (voir GoogleCalendar). Un enregistrement
  # lie porte `google_event_id` ; `google_updated_at` est l'horodatage Google de
  # la derniere version connue, c'est lui qui dit si Google a change depuis.
  # Pour une journee entiere, `start_time` est minuit heure de Paris et
  # `end_time`, s'il existe, le minuit du dernier jour (inclusif).
  GOOGLE_SYNC_COLUMNS = %w[google_event_id google_updated_at].freeze

  # Notification push automatique `reminder_minutes` avant un evenement a heure
  # precise (EventNotificationJob, chaque minute) : pas de Reminder a creer pour
  # etre prevenu d'un rendez-vous. 0 = aucune notification ; journee entiere et
  # echeances exclues (pas d'heure). `notified_at` vaut pour l'horaire en cours :
  # deplacer l'evenement ou changer le delai la rearme.
  NOTIFICATION_RESET_COLUMNS = %w[start_time reminder_minutes all_day].freeze

  # Occurrence d'une echeance notable (voir Deadline), nul pour un evenement ordinaire.
  belongs_to :deadline, optional: true

  before_save :rearm_notification, if: -> { persisted? && NOTIFICATION_RESET_COLUMNS.any? { |c| will_save_change_to_attribute?(c) } }

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

  # Evenements dont la notification est due a `now` : pas encore notifies, pas
  # encore commences, et dont le delai de prevenance est atteint.
  scope :notification_due, lambda { |now = Time.current|
    where(all_day: false, notified_at: nil)
      .where.not(event_type: "echeance")
      .where("reminder_minutes > 0")
      .where("start_time > ?", now)
      .where("start_time - make_interval(mins => reminder_minutes) <= ?", now)
  }

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

  def notification_payload(now = Time.current)
    start = start_time.in_time_zone
    details = ["#{self.class.time_until(start, now)}, à #{start.strftime('%H:%M')}", location.presence].compact
    {
      title: title,
      body: details.join(" · ").truncate(180),
      url: "/agenda",
      tag: "event-#{id}"
    }
  end

  # « Dans 1 h », « Dans 25 min », « Dans 1 h 30 », « Demain »...
  def self.time_until(time, now = Time.current)
    minutes = ((time - now) / 60.0).round
    return "Dans #{[minutes, 1].max} min" if minutes < 60
    return "Demain" if time.to_date == now.in_time_zone.to_date + 1 && minutes >= 6 * 60

    hours, rest = minutes.divmod(60)
    rest.zero? ? "Dans #{hours} h" : "Dans #{hours} h #{rest.to_s.rjust(2, '0')}"
  end

  private

  def rearm_notification
    self.notified_at = nil
  end

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
