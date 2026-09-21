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
