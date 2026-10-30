require "test_helper"

class ScriptsTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
    @folder = create(:script_folder, name: "Debunker des Étoiles", platform: "youtube")
  end

  test "les dossiers comptent leurs scripts et les non classes" do
    create(:script, script_folder: @folder)
    create(:script)

    get api_script_folders_path, headers: ACCEPT_JSON
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["folders"].first["scripts_count"]
    assert_equal "video", json["folders"].first["default_kind"]
    assert_equal 1, json["unfiled_count"]
  end

  test "l'index donne un extrait, le show le texte complet" do
    script = create(:script, script_folder: @folder, body: "Mot " * 200)

    get api_scripts_path, headers: ACCEPT_JSON
    item = JSON.parse(response.body).first
    assert_nil item["body"]
    assert item["excerpt"].length <= 220
    assert_equal "Debunker des Étoiles", item["folder_name"]
    assert_equal 200, item["word_count"]

    get api_script_path(script), headers: ACCEPT_JSON
    assert_equal script.body, JSON.parse(response.body)["body"]
  end

  test "creer, modifier, ranger puis supprimer un script" do
    assert_difference "Script.count", 1 do
      post api_scripts_path, params: { script: { title: "Sans titre", status: "draft", script_folder_id: @folder.id } }.to_json,
                             headers: JSON_HEADERS
    end
    assert_response :created
    id = JSON.parse(response.body)["id"]

    patch api_script_path(id), params: { script: { title: "Les chemtrails", body: "Accroche\n\n---\n\nSuite", kind: "thread",
                                                   script_folder_id: nil, published_on: "" } }.to_json,
                               headers: JSON_HEADERS
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["posts_count"]
    assert_nil Script.find(id).script_folder_id

    assert_difference "Script.count", -1 do
      delete api_script_path(id), headers: ACCEPT_JSON
    end
  end

  test "un script sans titre est refuse" do
    post api_scripts_path, params: { script: { title: "" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "creer, renommer et supprimer un dossier" do
    post api_script_folders_path, params: { script_folder: { name: "Compte X", platform: "x", handle: "@debunker" } }.to_json,
                                  headers: JSON_HEADERS
    assert_response :created
    folder = JSON.parse(response.body)
    assert_equal "thread", folder["default_kind"]

    patch api_script_folder_path(folder["id"]), params: { script_folder: { description: "Threads de debunk" } }.to_json,
                                                headers: JSON_HEADERS
    assert_response :success

    script = create(:script, script_folder_id: folder["id"])
    delete api_script_folder_path(folder["id"]), headers: ACCEPT_JSON
    assert_response :no_content
    assert_nil script.reload.script_folder_id
  end
end
