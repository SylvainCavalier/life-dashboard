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
FactoryBot.define do
  factory :trip_item do
    trip
    day { trip.start_date }
    kind { "visite" }
    title { "Fushimi Inari" }
    url { "https://example.com/fushimi" }
    start_time { nil }
    cost { nil }
    notes { nil }
    position { 0 }
  end
end
