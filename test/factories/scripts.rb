FactoryBot.define do
  factory :script_folder do
    sequence(:name) { |n| "Chaine #{n}" }
    platform { "youtube" }
  end

  factory :script do
    sequence(:title) { |n| "Script #{n}" }
    kind { "video" }
    status { "draft" }
    body { "" }
  end
end
