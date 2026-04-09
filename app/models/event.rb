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

  validates :title, presence: true
  validates :start_time, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validate :end_time_after_start_time, if: -> { end_time.present? }

  scope :ordered, -> { order(start_time: :asc) }
  scope :upcoming, -> { where("start_time >= ?", Time.current).ordered }
  scope :within_24h, -> { where(start_time: Time.current..24.hours.from_now).ordered }
  scope :within_1h, -> { where(start_time: Time.current..1.hour.from_now).ordered }

  private

  def end_time_after_start_time
    if end_time <= start_time
      errors.add(:end_time, "doit être après l'heure de début")
    end
  end
end
