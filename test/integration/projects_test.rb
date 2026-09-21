require "test_helper"

class ProjectsTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
    @project = create(:project)
  end

  test "l'index renvoie categorie et compteurs, sans les listes" do
    create(:project_skill, project: @project)

    get api_projects_path, headers: ACCEPT_JSON
    assert_response :success
    json = JSON.parse(response.body).find { |p| p["id"] == @project.id }
    assert_equal "jeu_video", json["category"]
    assert_equal 1, json["skills_count"]
    assert_nil json["skills"]
  end

  test "le show renvoie competences et liens" do
    create(:project_skill, project: @project)
    create(:project_link, project: @project)

    get api_project_path(@project), headers: ACCEPT_JSON
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal ["Blender"], json["skills"].map { |s| s["name"] }
    assert_equal 1, json["links"].size
  end

  test "creation avec categorie, et categorie par defaut" do
    post api_projects_path, params: { project: { name: "Apprendre le piano", category: "musique" } }.to_json,
                            headers: JSON_HEADERS
    assert_response :created
    assert_equal "musique", JSON.parse(response.body)["category"]

    post api_projects_path, params: { project: { name: "Site client" } }.to_json, headers: JSON_HEADERS
    assert_equal "developpement", JSON.parse(response.body)["category"]
  end

  test "une categorie inconnue repond 422" do
    post api_projects_path, params: { project: { name: "X", category: "tricot" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "la liste des categories" do
    get categories_api_projects_path, headers: ACCEPT_JSON
    assert_response :success
    assert_includes JSON.parse(response.body), { "value" => "jeu_de_role", "label" => "Jeu de rôle" }
  end

  test "cycle de vie d'une competence" do
    assert_difference "@project.project_skills.count", 1 do
      post api_project_project_skills_path(@project),
           params: { project_skill: { name: "Unreal Engine" } }.to_json, headers: JSON_HEADERS
    end
    assert_response :created
    skill = ProjectSkill.last
    assert_equal "a_apprendre", skill.status

    patch api_project_project_skill_path(@project, skill),
          params: { project_skill: { status: "acquise" } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "acquise", skill.reload.status

    patch api_project_project_skill_path(@project, skill),
          params: { project_skill: { status: "oubliee" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity

    delete api_project_project_skill_path(@project, skill), headers: ACCEPT_JSON
    assert_response :no_content
  end

  test "cycle de vie d'un lien" do
    post api_project_project_links_path(@project),
         params: { project_link: { title: "Tuto", url: "https://example.com/tuto" } }.to_json, headers: JSON_HEADERS
    assert_response :created
    link = ProjectLink.last

    post api_project_project_links_path(@project),
         params: { project_link: { title: "Piege", url: "javascript:alert(1)" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity

    delete api_project_project_link_path(@project, link), headers: ACCEPT_JSON
    assert_response :no_content
  end

  test "une competence d'un autre projet est introuvable" do
    other = create(:project, name: "Visual novel")
    skill = create(:project_skill, project: other)

    patch api_project_project_skill_path(@project, skill),
          params: { project_skill: { status: "acquise" } }.to_json, headers: JSON_HEADERS
    assert_response :not_found
  end

  test "les taches d'un projet sont separees de la to-do list generale" do
    general = Task.create!(description: "Tache generale")

    post api_tasks_path, params: { task: { description: "Modeliser le heros", project_id: @project.id } }.to_json,
                         headers: JSON_HEADERS
    assert_response :created
    project_task_id = JSON.parse(response.body)["id"]

    get api_tasks_path, headers: ACCEPT_JSON
    assert_equal [general.id], JSON.parse(response.body).map { |t| t["id"] }

    get api_tasks_path(project_id: @project.id), headers: ACCEPT_JSON
    assert_equal [project_task_id], JSON.parse(response.body).map { |t| t["id"] }
  end

  test "un document peut etre rattache a un projet" do
    file = Rack::Test::UploadedFile.new(StringIO.new("contenu"), "text/plain", original_filename: "gdd.txt")
    post api_documents_path,
         params: { domain: "projects", project_id: @project.id, name: "Game design document", category: "brief", file: file },
         headers: ACCEPT_JSON
    assert_response :created
    assert_equal @project.id, JSON.parse(response.body)["project_id"]

    get api_documents_path(project_id: @project.id), headers: ACCEPT_JSON
    assert_equal ["Game design document"], JSON.parse(response.body).map { |d| d["name"] }
  end
end
