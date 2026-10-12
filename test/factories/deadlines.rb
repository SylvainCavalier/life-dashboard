FactoryBot.define do
  factory :deadline do
    title { "Taxe foncière" }
    category { "impots" }
    due_on { Date.new(2026, 10, 15) }
    recurrence { "yearly" }
    amount { 1240 }
  end
end
