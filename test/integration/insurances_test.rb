require "test_helper"

class InsurancesTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
    @insurance = create(:insurance, renewal_date: Date.current + 20)
  end

  test "l'index renvoie compteurs, cotisation annuelle et echeance" do
    create(:insurance_coverage, insurance: @insurance)
    create(:insured_item, insurance: @insurance)

    get api_insurances_path, headers: ACCEPT_JSON
    assert_response :success
    json = JSON.parse(response.body).find { |i| i["id"] == @insurance.id }
    assert_equal 1, json["coverages_count"]
    assert_equal ["Appartement de Créteil"], json["item_names"]
    assert_equal "222.0", json["annual_premium"]
    assert_equal (Date.current + 20).iso8601, json["next_renewal_on"]
    assert_nil json["coverages"]
  end

  test "le show renvoie garanties et biens assures avec le bien immobilier" do
    property = Property.create!(name: "Appartement Créteil", property_type: "appartement")
    create(:insurance_coverage, insurance: @insurance)
    create(:insured_item, insurance: @insurance, property: property)

    get api_insurance_path(@insurance), headers: ACCEPT_JSON
    json = JSON.parse(response.body)
    assert_equal ["Dégâts des eaux"], json["coverages"].map { |c| c["name"] }
    assert_equal "Appartement Créteil", json["items"].first["property_name"]
  end

  test "creation, modification et suppression d'un contrat" do
    assert_difference "Insurance.count", 1 do
      post api_insurances_path, params: { insurance: { name: "Auto", insurance_type: "auto", premium: 600 } }.to_json,
                                headers: JSON_HEADERS
    end
    assert_response :created
    id = JSON.parse(response.body)["id"]

    patch api_insurance_path(id), params: { insurance: { status: "resiliee" } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "resiliee", Insurance.find(id).status

    assert_difference "Insurance.count", -1 do
      delete api_insurance_path(id), headers: ACCEPT_JSON
    end
    assert_response :no_content
  end

  test "un type inconnu repond 422" do
    post api_insurances_path, params: { insurance: { name: "X", insurance_type: "spatiale" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "cycle de vie d'une garantie" do
    post api_insurance_insurance_coverages_path(@insurance),
         params: { insurance_coverage: { name: "Vol", included: false } }.to_json, headers: JSON_HEADERS
    assert_response :created
    coverage = @insurance.insurance_coverages.last
    assert_not coverage.included

    patch api_insurance_insurance_coverage_path(@insurance, coverage),
          params: { insurance_coverage: { included: true, deductible: "300 €" } }.to_json, headers: JSON_HEADERS
    assert_equal "300 €", coverage.reload.deductible

    delete api_insurance_insurance_coverage_path(@insurance, coverage), headers: ACCEPT_JSON
    assert_response :no_content
    assert_empty @insurance.insurance_coverages.reload
  end

  test "une garantie d'un autre contrat est introuvable" do
    other = create(:insurance_coverage)
    patch api_insurance_insurance_coverage_path(@insurance, other),
          params: { insurance_coverage: { name: "X" } }.to_json, headers: JSON_HEADERS
    assert_response :not_found
  end

  test "cycle de vie d'un bien assure" do
    post api_insurance_insured_items_path(@insurance),
         params: { insured_item: { name: "MacBook", kind: "objet", value: 2500 } }.to_json, headers: JSON_HEADERS
    assert_response :created
    item = @insurance.insured_items.last

    delete api_insurance_insured_item_path(@insurance, item), headers: ACCEPT_JSON
    assert_response :no_content
  end

  test "les documents se filtrent par contrat" do
    document = Document.new(name: "CG", domain: "insurance", category: "general_terms", insurance: @insurance)
    document.file.attach(io: StringIO.new("%PDF-1.4"), filename: "cg.pdf", content_type: "application/pdf")
    document.save!
    other = Document.new(name: "Autre", domain: "general")
    other.file.attach(io: StringIO.new("x"), filename: "x.txt", content_type: "text/plain")
    other.save!

    get api_documents_path, params: { insurance_id: @insurance.id }, headers: ACCEPT_JSON
    assert_equal [document.id], JSON.parse(response.body).map { |d| d["id"] }
  end

  test "la fiche du corpus d'Alfred dit ce qui est couvert et a quelles conditions" do
    property = Property.create!(name: "Appartement Créteil", property_type: "appartement")
    create(:insured_item, insurance: @insurance, property: property)
    create(:insurance_coverage, insurance: @insurance)
    create(:insurance_coverage, insurance: @insurance, name: "Vol", included: false, ceiling: nil, deductible: nil, conditions: nil)

    text = Alfred::Corpus::RecordRenderer.new(@insurance.reload).text

    assert_match "bien immobilier : Appartement Créteil", text
    assert_match "Dégâts des eaux : couverte ; plafond : valeur à neuf ; franchise : 150 € ; conditions : Fuites accidentelles uniquement", text
    assert_match "Vol : NON couverte", text
    assert_equal @insurance, Alfred::Corpus.root_for(@insurance.insurance_coverages.first)
  end

  test "Alfred peut lire et proposer d'ecrire les trois modeles" do
    %w[Insurance InsuranceCoverage InsuredItem].each do |model|
      assert_includes Alfred::DataAccess::READABLE.keys, model
      assert_includes Alfred::DataAccess::WRITABLE.keys, model
    end
    assert_includes Alfred::Prompt.stable_text, "## Assurances"
  end
end
