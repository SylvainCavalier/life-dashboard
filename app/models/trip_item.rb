# == Schema Information
#
# Table name: trip_items
#
#  id         :bigint           not null, primary key
#  cost       :decimal(10, 2)
#  day        :date             not null
#  kind       :string           default("autre"), not null
#  notes      :text
#  position   :integer          default(0), not null
#  start_time :time
#  title      :string           not null
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  trip_id    :bigint           not null
#
# Indexes
#
#  index_trip_items_on_trip_id          (trip_id)
#  index_trip_items_on_trip_id_and_day  (trip_id,day)
#
# Foreign Keys
#
#  fk_rails_...  (trip_id => trips.id)
#
class TripItem < ApplicationRecord
  KINDS = %w[hotel restaurant visite transport autre].freeze

  KIND_LABELS = {
    "hotel" => "Hôtel",
    "restaurant" => "Restaurant",
    "visite" => "Visite",
    "transport" => "Transport",
    "autre" => "Autre"
  }.freeze

  belongs_to :trip

  before_create :assign_position

  validates :title, :day, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :url, format: { with: %r{\Ahttps?://}i, message: "doit commencer par http:// ou https://" },
                  allow_blank: true
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :day_within_trip, if: -> { trip.present? && day.present? }

  scope :ordered, -> { order(Arel.sql("day ASC, start_time ASC NULLS LAST, position ASC, id ASC")) }

  # JSON shape shared by the trips and trip_items controllers. `start_time` is
  # a bare time column: without the strftime Rails would serialise it as
  # "2000-01-01T09:00:00.000Z".
  def api_attributes
    {
      id: id,
      trip_id: trip_id,
      day: day,
      kind: kind,
      title: title,
      url: url,
      start_time: start_time&.strftime("%H:%M"),
      cost: cost,
      notes: notes,
      position: position,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def assign_position
    return unless position.zero?

    self.position = (trip.trip_items.where(day: day).maximum(:position) || -1) + 1
  end

  def day_within_trip
    return if day.between?(trip.start_date, trip.end_date)

    errors.add(:day,
               "doit être compris entre le #{trip.start_date.strftime('%d/%m/%Y')} et le #{trip.end_date.strftime('%d/%m/%Y')}")
  end
end
