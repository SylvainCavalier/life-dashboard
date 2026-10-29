FactoryBot.define do
  factory :loan do
    direction { "lent" }
    kind { "object" }
    person_name { "Paul" }
    item { "Perceuse" }
    started_on { Date.new(2026, 9, 1) }
  end
end
