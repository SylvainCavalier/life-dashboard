require "test_helper"

class VehiclesTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
    @vehicle = create(:vehicle, service_interval_months: 12, technical_inspection_due_on: Date.current + 20)
  end

  test "l'index renvoie echeances et compteurs" do
    create(:vehicle_intervention, vehicle: @vehicle, occurred_on: Date.current - 30)

    get api_vehicles_path, headers: ACCEPT_JSON
    assert_response :success
    json = JSON.parse(response.body).find { |v| v["id"] == @vehicle.id }
    assert_equal "due_soon", json["inspection_status"]
    assert_equal ((Date.current - 30) >> 12).iso8601, json["next_service_on"]
    assert_equal 1, json["interventions_count"]
    assert_nil json["interventions"]
  end

  test "le show renvoie le carnet et les contrats qui couvrent le vehicule" do
    create(:vehicle_intervention, vehicle: @vehicle)
    insurance = create(:insurance, name: "Auto Clio", insurance_type: "auto", claims_phone: "0800 000 000")
    create(:insured_item, insurance: insurance, kind: "vehicule", name: "Clio", vehicle: @vehicle)

    get api_vehicle_path(@vehicle), headers: ACCEPT_JSON
    json = JSON.parse(response.body)
    assert_equal ["Révision des 60 000 km"], json["interventions"].map { |i| i["title"] }
    assert_equal [["Auto Clio", "0800 000 000"]], json["insurances"].map { |i| i.values_at("name", "claims_phone") }

    get api_insurance_path(insurance), headers: ACCEPT_JSON
    assert_equal "Clio", JSON.parse(response.body)["items"].first["vehicle_name"]
  end

  test "creation, modification et suppression d'un vehicule" do
    assert_difference "Vehicle.count", 1 do
      post api_vehicles_path, params: { vehicle: { name: "Bonneville", vehicle_type: "moto", registration_number: "gh-456-ij" } }.to_json,
                              headers: JSON_HEADERS
    end
    assert_response :created
    id = JSON.parse(response.body)["id"]
    assert_equal "GH-456-IJ", Vehicle.find(id).registration_number

    patch api_vehicle_path(id), params: { vehicle: { status: "vendu", sold_on: Date.current } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "vendu", Vehicle.find(id).status

    assert_difference "Vehicle.count", -1 do
      delete api_vehicle_path(id), headers: ACCEPT_JSON
    end
    assert_response :no_content
  end

  test "un type inconnu repond 422" do
    post api_vehicles_path, params: { vehicle: { name: "X", vehicle_type: "fusee" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "une intervention renvoie la fiche du vehicule mise a jour" do
    post api_vehicle_vehicle_interventions_path(@vehicle),
         params: { vehicle_intervention: { occurred_on: Date.current, kind: "controle_technique", outcome: "favorable", mileage: 70_000 } }.to_json,
         headers: JSON_HEADERS
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Contrôle technique", json["intervention"]["title"]
    assert_equal (Date.current >> 24).iso8601, json["vehicle"]["next_inspection_on"]
    assert_equal 70_000, json["vehicle"]["mileage"]

    intervention = @vehicle.vehicle_interventions.last
    patch api_vehicle_vehicle_intervention_path(@vehicle, intervention),
          params: { vehicle_intervention: { cost: 78 } }.to_json, headers: JSON_HEADERS
    assert_equal "78.0", JSON.parse(response.body)["intervention"]["cost"]

    delete api_vehicle_vehicle_intervention_path(@vehicle, intervention), headers: ACCEPT_JSON
    assert_response :success
    assert_empty JSON.parse(response.body)["vehicle"]["interventions"]
  end

  test "une intervention d'un autre vehicule est introuvable" do
    other = create(:vehicle_intervention)
    patch api_vehicle_vehicle_intervention_path(@vehicle, other),
          params: { vehicle_intervention: { title: "X" } }.to_json, headers: JSON_HEADERS
    assert_response :not_found
  end

  test "les documents se filtrent par vehicule" do
    document = Document.new(name: "Carte grise", domain: "vehicles", category: "registration", vehicle: @vehicle)
    document.file.attach(io: StringIO.new("%PDF-1.4"), filename: "cg.pdf", content_type: "application/pdf")
    document.save!
    other = Document.new(name: "Autre", domain: "general")
    other.file.attach(io: StringIO.new("x"), filename: "x.txt", content_type: "text/plain")
    other.save!

    get api_documents_path, params: { vehicle_id: @vehicle.id }, headers: ACCEPT_JSON
    assert_equal [document.id], JSON.parse(response.body).map { |d| d["id"] }
    assert_equal "/vehicles/#{@vehicle.id}", Alfred::Corpus.document_path(document)
    assert_equal "Vehicule : Clio", Alfred::Corpus.document_text(document)
  end

  test "la fiche du corpus d'Alfred rend le carnet d'entretien et les contrats" do
    create(:vehicle_intervention, vehicle: @vehicle, description: "Vidange et filtres")
    create(:vehicle_intervention, vehicle: @vehicle, kind: "controle_technique", title: "CT", outcome: "contre_visite",
                                  occurred_on: Date.new(2026, 5, 4), mileage: nil, cost: nil, garage: nil)
    insurance = create(:insurance, name: "Auto Clio", insurance_type: "auto", insurer: "MAIF")
    create(:insured_item, insurance: insurance, kind: "vehicule", name: "Clio", vehicle: @vehicle)

    text = Alfred::Corpus::RecordRenderer.new(@vehicle.reload).text

    assert_match "Assure par :\n- Auto Clio - MAIF (active)", text
    assert_match "10/03/2026 · Entretien / révision : Révision des 60 000 km (60000 km ; 289.0 EUR ; Garage du Centre) : Vidange et filtres", text
    assert_match "04/05/2026 · Contrôle technique : CT (resultat : Défavorable (contre-visite))", text
    assert_equal @vehicle, Alfred::Corpus.root_for(@vehicle.vehicle_interventions.first)
    assert_match "vehicule : Clio", Alfred::Corpus::RecordRenderer.new(insurance.reload).text
  end

  test "Alfred peut lire et proposer d'ecrire vehicules et carnet" do
    %w[Vehicle VehicleIntervention].each do |model|
      assert_includes Alfred::DataAccess::READABLE.keys, model
      assert_includes Alfred::DataAccess::WRITABLE.keys, model
    end
    assert_includes Alfred::DataAccess.readable_extras("Vehicle"), "next_inspection_on"
    assert_includes Alfred::Prompt.stable_text, "## Véhicules"
    assert_includes Reminder::REMINDABLE_TYPES, "Vehicle"
  end
end
