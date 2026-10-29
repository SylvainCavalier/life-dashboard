FactoryBot.define do
  factory :warranty do
    name { "Lave-linge" }
    brand { "Bosch" }
    category { "electromenager" }
    store { "Darty" }
    purchased_on { Date.new(2025, 3, 15) }
    duration_months { 24 }
    price { 549 }
  end
end
