# == Schema Information
#
# Table name: trips
#
#  id             :bigint           not null, primary key
#  country_code   :string(2)        not null
#  departure_city :string           default("Paris")
#  destination    :string           not null
#  end_date       :date             not null
#  notes          :text
#  start_date     :date             not null
#  status         :string           default("envisage"), not null
#  travelers      :integer          default(1), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_trips_on_country_code  (country_code)
#  index_trips_on_start_date    (start_date)
#  index_trips_on_status        (status)
#
class Trip < ApplicationRecord
  STATUSES = %w[envisage confirme annule].freeze

  STATUS_LABELS = {
    "envisage" => "Envisagé",
    "confirme" => "Confirmé",
    "annule" => "Annulé"
  }.freeze

  has_one :trip_plan, dependent: :destroy
  has_many :trip_items, dependent: :destroy

  before_validation :normalize_country_code

  validates :destination, presence: true
  validates :country_code, presence: true,
                           format: { with: /\A[a-z]{2}\z/, message: "doit être un code pays ISO à deux lettres" }
  validates :start_date, :end_date, presence: true
  validates :travelers, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validate :end_date_after_start_date, if: -> { start_date.present? && end_date.present? }

  scope :ordered, -> { order(start_date: :desc) }
  scope :not_cancelled, -> { where.not(status: "annule") }
  scope :past, -> { where("end_date < ?", Date.current) }
  scope :upcoming, -> { where("end_date >= ?", Date.current) }
  scope :visited, -> { past.not_cancelled }

  # Country codes of every trip already completed (and not cancelled), used to
  # colour the world map.
  def self.visited_country_codes
    visited.distinct.pluck(:country_code)
  end

  def past?
    end_date < Date.current
  end

  def cancelled?
    status == "annule"
  end

  def visited?
    past? && !cancelled?
  end

  def duration_days
    (end_date - start_date).to_i + 1
  end

  def days
    (start_date..end_date).to_a
  end

  # Fingerprint of the attributes the AI report depends on. Stored on the plan
  # at generation time so the UI can flag a report as outdated.
  def plan_fingerprint
    Digest::SHA256.hexdigest(
      [destination, country_code, start_date, end_date, travelers, departure_city].join("|")
    )
  end

  # Enqueues the generation of the AI report. Returns the TripPlan record.
  # Concurrent calls (double click, Alfred + UI) are serialised by the row
  # lock: the second caller sees the plan already pending and does not
  # enqueue a second job. A plan stuck in progress (dyno restarted mid-job)
  # can be relaunched.
  def generate_plan!
    with_lock do
      plan = trip_plan || build_trip_plan
      return plan if plan.persisted? && plan.in_progress? && !plan.stuck?

      plan.update!(status: "pending", error: nil, requested_at: Time.current, started_at: nil)
      TripPlanJob.perform_later(plan.id)
      plan
    end
  end

  private

  def normalize_country_code
    self.country_code = country_code.to_s.strip.downcase.presence
  end

  def end_date_after_start_date
    return if end_date >= start_date

    errors.add(:end_date, "doit être postérieure ou égale à la date de départ")
  end
end
