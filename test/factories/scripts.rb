# == Schema Information
#
# Table name: scripts
#
#  id               :bigint           not null, primary key
#  body             :text             default(""), not null
#  kind             :string           default("video"), not null
#  notes            :text
#  planned_on       :date
#  published_on     :date
#  published_url    :string
#  status           :string           default("idea"), not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  script_folder_id :bigint
#
# Indexes
#
#  index_scripts_on_script_folder_id  (script_folder_id)
#  index_scripts_on_status            (status)
#  index_scripts_on_updated_at        (updated_at)
#
# Foreign Keys
#
#  fk_rails_...  (script_folder_id => script_folders.id) ON DELETE => nullify
#
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
