require "test_helper"

class WarrantiesTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
  end

  def pdf_upload
    Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4\n%%EOF\n"), "application/pdf", original_filename: "facture.pdf")
  end

  test "l'index trie par fin de garantie et renvoie statut et jours restants" do
    later = create(:warranty, name: "Télévision", purchased_on: Date.current, duration_months: 24)
    soon = create(:warranty, name: "Aspirateur", purchased_on: Date.current - 700, duration_months: 24)

    get api_warranties_path, headers: ACCEPT_JSON
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [soon.id, later.id], json.map { |w| w["id"] }
    assert_equal "expiring", json.first["status"]
    assert_equal (soon.ends_on - Date.current).to_i, json.first["days_left"]
    assert_equal "Électroménager", json.first["category_label"]
    assert_nil json.first["receipt"]
  end

  test "creation, modification et suppression d'une garantie" do
    assert_difference "Warranty.count", 1 do
      post api_warranties_path,
           params: { warranty: { name: "MacBook", category: "informatique", purchased_on: "2026-01-10", duration_months: 12 } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "2027-01-10", json["ends_on"]

    patch api_warranty_path(json["id"]), params: { warranty: { ends_on: "2029-01-10", notes: "AppleCare+" } }.to_json,
                                         headers: JSON_HEADERS
    assert_response :success
    assert_equal Date.new(2029, 1, 10), Warranty.find(json["id"]).ends_on

    assert_difference "Warranty.count", -1 do
      delete api_warranty_path(json["id"]), headers: ACCEPT_JSON
    end
    assert_response :no_content
  end

  test "une garantie incomplete repond 422" do
    post api_warranties_path, params: { warranty: { name: "Sans date" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "la facture part en multipart, puis se retire" do
    post api_warranties_path,
         params: { warranty: { name: "Four", purchased_on: "2026-05-02", duration_months: "24", ends_on: "", receipt: pdf_upload } },
         headers: ACCEPT_JSON
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "facture.pdf", json["receipt"]["filename"]
    assert_equal "2028-05-02", json["ends_on"]

    warranty = Warranty.find(json["id"])
    assert warranty.receipt.attached?

    patch api_warranty_path(warranty), params: { warranty: { name: "Four", remove_receipt: "1" } }, headers: ACCEPT_JSON
    assert_response :success
    assert_not warranty.reload.receipt.attached?
  end

  test "un nouveau fichier n'est pas retire par remove_receipt" do
    warranty = create(:warranty)

    patch api_warranty_path(warranty), params: { warranty: { receipt: pdf_upload, remove_receipt: "1" } }, headers: ACCEPT_JSON
    assert_response :success
    assert warranty.reload.receipt.attached?
  end
end
