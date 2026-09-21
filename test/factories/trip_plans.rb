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
FactoryBot.define do
  factory :trip_plan do
    trip
    status { "done" }
    model { "gpt-test" }
    requested_at { 10.minutes.ago }
    started_at { 9.minutes.ago }
    generated_at { 5.minutes.ago }
    estimated_total_eur { 1850.0 }
    input_fingerprint { trip&.plan_fingerprint }
    content do
      {
        "summary" => "Le Japon au printemps.",
        "history" => "Une longue histoire.",
        "practical_info" => [{ "label" => "Monnaie", "value" => "Yen" }],
        "rules" => [{ "title" => "Pourboire", "detail" => "Ne se pratique pas." }],
        "costs" => {
          "flights_eur" => 900.0, "lodging_per_night_eur" => 80.0, "food_per_day_eur" => 35.0,
          "activities_eur" => 150.0, "total_eur" => 1850.0, "local_currency" => "JPY",
          "exchange_rate_note" => "1 EUR = 160 JPY", "assumptions" => ["Vol économique"]
        },
        "places" => [{ "name" => "Fushimi Inari", "description" => "Sanctuaire", "city" => "Kyoto",
                       "price_eur" => 0.0, "price_note" => "Gratuit", "booking_url" => nil }],
        "restaurants" => [{ "name" => "Ichiran", "cuisine" => "Ramen", "city" => "Tokyo",
                            "price_range" => "€", "url" => "https://example.com", "note" => nil }],
        "itinerary" => [{ "day_number" => 1, "title" => "Arrivée",
                          "activities" => [{ "moment" => "soir", "title" => "Dîner", "description" => "Ramen",
                                             "place_name" => "Ichiran", "url" => nil }] }],
        "sources" => [{ "title" => "Exemple", "url" => "https://example.com" }]
      }
    end

    trait :pending do
      status { "pending" }
      started_at { nil }
      generated_at { nil }
      estimated_total_eur { nil }
      input_fingerprint { nil }
      content { {} }
    end

    trait :running do
      status { "running" }
      generated_at { nil }
      estimated_total_eur { nil }
      input_fingerprint { nil }
      content { {} }
    end

    trait :failed do
      status { "failed" }
      error { "OpenAI::Errors::APITimeoutError: timeout" }
    end
  end
end
