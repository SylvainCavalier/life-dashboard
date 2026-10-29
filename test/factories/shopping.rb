FactoryBot.define do
  factory :shopping_item do
    sequence(:name) { |n| "Article #{n}" }
  end

  factory :shopping_preset do
    sequence(:name) { |n| "Habituel #{n}" }
  end
end
