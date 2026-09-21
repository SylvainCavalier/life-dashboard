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
require "test_helper"

class TripPlanTest < ActiveSupport::TestCase
  test "le statut est controle" do
    assert_not build(:trip_plan, status: "unknown").valid?
  end

  test "in_progress, done et stuck" do
    assert build(:trip_plan, :pending, requested_at: 1.minute.ago).in_progress?
    assert_not build(:trip_plan, :pending, requested_at: 1.minute.ago).stuck?
    assert build(:trip_plan, :running, requested_at: 20.minutes.ago).stuck?
    assert build(:trip_plan).done?
    assert_not build(:trip_plan, :failed).in_progress?
  end
end
