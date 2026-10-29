require "test_helper"

class LoansTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
  end

  test "l'index met les prets en cours d'abord et filtre par contact" do
    contact = Contact.create!(first_name: "Julie")
    returned = create(:loan, item: "Tente", returned_on: Date.new(2026, 9, 10))
    current = create(:loan, contact: contact, direction: "borrowed", kind: "money", amount: 50, item: nil)

    get api_loans_path, headers: ACCEPT_JSON
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [current.id, returned.id], json.map { |l| l["id"] }
    assert_equal "Julie", json.first["person_name"]
    assert_equal({ "id" => contact.id, "name" => "Julie" }, json.first["contact"])
    assert_equal "50.0", json.first["remaining_amount"]
    assert_equal "returned", json.last["status"]

    get api_loans_path(contact_id: contact.id), headers: ACCEPT_JSON
    assert_equal [current.id], JSON.parse(response.body).map { |l| l["id"] }
  end

  test "creation, retour et suppression d'un pret" do
    assert_difference "Loan.count", 1 do
      post api_loans_path,
           params: { loan: { direction: "lent", kind: "object", person_name: "Paul", item: "Perceuse",
                             started_on: "2026-10-01", due_on: "", contact_id: "" } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "ongoing", json["status"]
    assert_nil Loan.find(json["id"]).due_on

    patch api_loan_path(json["id"]), params: { loan: { returned_on: "2026-10-20" } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "returned", JSON.parse(response.body)["status"]

    assert_difference "Loan.count", -1 do
      delete api_loan_path(json["id"]), headers: ACCEPT_JSON
    end
    assert_response :no_content
  end

  test "un pret incomplet repond 422 avec des messages lisibles" do
    post api_loans_path, params: { loan: { direction: "lent", kind: "money", started_on: "2026-10-01" } }.to_json,
                         headers: JSON_HEADERS
    assert_response :unprocessable_entity
    errors = JSON.parse(response.body)["errors"]
    assert_includes errors, "Personne requise (un contact ou un nom)"
    assert_includes errors, "Montant requis pour un pret d'argent"
  end
end
