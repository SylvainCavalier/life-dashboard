# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  category    :string           default("developpement"), not null
#  description :text
#  github_url  :string
#  name        :string
#  notes       :text
#  priority    :integer          default(0)
#  progress    :integer          default(0)
#  site_url    :string
#  status      :string           default("en_cours")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_projects_on_category  (category)
#
FactoryBot.define do
  factory :project do
    name { "Jeu vidéo 3D solo" }
    category { "jeu_video" }
    status { "en_cours" }
    priority { 3 }
    progress { 10 }
    description { nil }
    notes { nil }
  end

  factory :project_skill do
    project
    name { "Blender" }
    status { "a_apprendre" }
  end

  factory :project_link do
    project
    title { "Documentation Unreal Engine" }
    url { "https://dev.epicgames.com/documentation" }
  end
end
