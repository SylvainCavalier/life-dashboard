# == Schema Information
#
# Table name: trip_plans
#
#  id                  :bigint           not null, primary key
#  content             :jsonb            not null
#  error               :text
#  estimated_total_eur :decimal(10, 2)
#  generated_at        :datetime
#  input_fingerprint   :string
#  model               :string
#  requested_at        :datetime
#  started_at          :datetime
#  status              :string           default("pending"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  trip_id             :bigint           not null
#
# Indexes
#
#  index_trip_plans_on_trip_id  (trip_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (trip_id => trips.id)
#
class TripPlan < ApplicationRecord
  STATUSES = %w[pending running done failed].freeze

  # Beyond this delay a plan still "in progress" is considered stuck (the web
  # dyno restarted while the job was running) and can be relaunched.
  STUCK_AFTER = 15.minutes

  belongs_to :trip

  validates :status, inclusion: { in: STATUSES }

  def in_progress?
    %w[pending running].include?(status)
  end

  def done?
    status == "done"
  end

  def stuck?
    in_progress? && requested_at.present? && requested_at < STUCK_AFTER.ago
  end

  # True when the trip changed (dates, destination...) after the report was
  # generated.
  def outdated?
    done? && input_fingerprint.present? && input_fingerprint != trip.plan_fingerprint
  end
end
