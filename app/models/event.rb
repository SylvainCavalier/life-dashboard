# == Schema Information
#
# Table name: events
#
#  id               :bigint           not null, primary key
#  all_day          :boolean          default(FALSE)
#  color            :string           default("#6366f1")
#  description      :text
#  end_time         :datetime
#  event_type       :string           default("autre"), not null
#  location         :string
#  reminder_minutes :integer          default(60)
#  start_time       :datetime         not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_events_on_event_type  (event_type)
#  index_events_on_start_time  (start_time)
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
