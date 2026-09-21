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
require "test_helper"

class TripItemTest < ActiveSupport::TestCase
  test "un item valide s'enregistre" do
    assert build(:trip_item).valid?
  end

  test "le jour doit etre compris dans les dates du voyage" do
    trip = create(:trip)
    item = build(:trip_item, trip: trip, day: trip.end_date + 1)
    assert_not item.valid?
    assert_includes item.errors[:day].join, "compris"
  end

  test "le type et l'url sont controles" do
    assert_not build(:trip_item, kind: "musee").valid?
    assert_not build(:trip_item, url: "www.example.com").valid?
    assert build(:trip_item, url: "").valid?
    assert build(:trip_item, url: "https://example.com").valid?
  end

  test "la position s'incremente par jour" do
    trip = create(:trip)
    first = create(:trip_item, trip: trip)
    second = create(:trip_item, trip: trip)
    other_day = create(:trip_item, trip: trip, day: trip.start_date + 1)

    assert_equal 0, first.position
    assert_equal 1, second.position
    assert_equal 0, other_day.position
  end

  test "api_attributes serialise l'heure en HH:MM" do
    item = build(:trip_item, start_time: "09:30")
    assert_equal "09:30", item.api_attributes[:start_time]
    assert_nil build(:trip_item).api_attributes[:start_time]
  end
end
