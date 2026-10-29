require "test_helper"

class ShoppingTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
  end

  test "ajout d'un lot, coche, retrait puis remise a zero de la liste" do
    create(:shopping_item, name: "Lait")

    post api_shopping_items_path, params: { names: %w[Oeufs lait] }.to_json, headers: JSON_HEADERS
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal ["Oeufs"], json["added"].map { |i| i["name"] }
    assert_equal ["lait"], json["skipped"]

    oeufs = ShoppingItem.find_by!(name: "Oeufs")
    patch api_shopping_item_path(oeufs), params: { shopping_item: { checked: true } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert JSON.parse(response.body)["checked"]

    get api_shopping_items_path, headers: ACCEPT_JSON
    assert_equal %w[Lait Oeufs], JSON.parse(response.body).map { |i| i["name"] }

    delete api_shopping_item_path(oeufs), headers: ACCEPT_JSON
    assert_response :no_content

    delete clear_api_shopping_items_path, headers: ACCEPT_JSON
    assert_response :success
    assert_equal 1, JSON.parse(response.body)["removed"]
    assert_equal 0, ShoppingItem.count
  end

  test "un seul nom par shopping_item[name], vide refuse" do
    post api_shopping_items_path, params: { shopping_item: { name: "Cafe" } }.to_json, headers: JSON_HEADERS
    assert_response :created
    assert_equal ["Cafe"], ShoppingItem.pluck(:name)

    post api_shopping_items_path, params: { shopping_item: { name: "x" * 101 } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "cartes d'articles habituels" do
    post api_shopping_presets_path, params: { shopping_preset: { name: "baguette", icon: "🥖" } }.to_json, headers: JSON_HEADERS
    assert_response :created
    preset = ShoppingPreset.last
    assert_equal "Baguette", preset.name

    post api_shopping_presets_path, params: { shopping_preset: { name: "BAGUETTE" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity

    get api_shopping_presets_path, headers: ACCEPT_JSON
    assert_equal [{ "name" => "Baguette", "icon" => "🥖" }], JSON.parse(response.body).map { |p| p.slice("name", "icon") }

    delete api_shopping_preset_path(preset), headers: ACCEPT_JSON
    assert_response :no_content
  end
end
