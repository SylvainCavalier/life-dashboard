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
FactoryBot.define do
  factory :trip do
    destination { "Kyoto et Tokyo" }
    country_code { "jp" }
    start_date { 30.days.from_now.to_date }
    end_date { 37.days.from_now.to_date }
    travelers { 2 }
    departure_city { "Paris" }
    status { "envisage" }
    notes { nil }

    trait :past do
      start_date { 60.days.ago.to_date }
      end_date { 53.days.ago.to_date }
      status { "confirme" }
    end

    trait :cancelled do
      status { "annule" }
    end
  end
end
