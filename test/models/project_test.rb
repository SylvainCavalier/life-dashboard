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
require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "la categorie doit faire partie de la liste" do
    assert build(:project, category: "musique").valid?
    project = build(:project, category: "tricot")
    assert_not project.valid?
    assert project.errors[:category].any?
  end

  test "chaque categorie a un libelle" do
    assert_equal Project::CATEGORIES.sort, Project::CATEGORY_LABELS.keys.sort
  end

  test "api_attributes expose les compteurs" do
    project = create(:project)
    create(:project_skill, project: project, status: "acquise")
    create(:project_skill, project: project, name: "Unreal Engine")
    create(:project_link, project: project)
    project.tasks.create!(description: "Modeliser le heros", completed: true)
    project.tasks.create!(description: "Animer le heros")

    json = project.reload.api_attributes
    assert_equal 2, json[:skills_count]
    assert_equal 1, json[:skills_acquired_count]
    assert_equal 2, json[:tasks_count]
    assert_equal 1, json[:tasks_completed_count]
    assert_equal 1, json[:links_count]
    assert_equal "Jeu vidéo", json[:category_label]
    assert_nil json[:skills], "les listes ne sont renvoyees qu'avec full: true"
  end

  test "supprimer un projet supprime ses taches, competences et liens" do
    project = create(:project)
    create(:project_skill, project: project)
    create(:project_link, project: project)
    project.tasks.create!(description: "Tache du projet")
    general = Task.create!(description: "Tache generale")

    assert_difference -> { ProjectSkill.count } => -1, -> { ProjectLink.count } => -1, -> { Task.count } => -1 do
      project.destroy
    end
    assert Task.exists?(general.id)
  end

  test "les positions des competences s'incrementent" do
    project = create(:project)
    first = create(:project_skill, project: project)
    second = create(:project_skill, project: project, name: "Unreal Engine")
    assert_equal [0, 1], [first.position, second.position]
  end

  test "un lien doit etre une URL http(s)" do
    assert_not build(:project_link, url: "javascript:alert(1)").valid?
    assert build(:project_link, url: "https://example.com").valid?
  end
end
