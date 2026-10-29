# == Schema Information
#
# Table name: vehicles
#
#  id                          :bigint           not null, primary key
#  brand                       :string
#  color                       :string
#  engine_displacement         :integer
#  first_registration_on       :date
#  fiscal_power                :integer
#  fuel                        :string
#  mileage                     :integer
#  mileage_on                  :date
#  model                       :string
#  name                        :string           not null
#  notes                       :text
#  oil_type                    :string
#  power_hp                    :integer
#  purchase_mileage            :integer
#  purchase_price              :decimal(10, 2)
#  purchased_on                :date
#  registration_number         :string
#  sale_price                  :decimal(10, 2)
#  service_interval_km         :integer
#  service_interval_months     :integer
#  sold_on                     :date
#  status                      :string           default("active"), not null
#  technical_inspection_due_on :date
#  tire_size                   :string
#  vehicle_type                :string           default("voiture"), not null
#  version                     :string
#  vin                         :string
#  year                        :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
require "test_helper"

class VehicleTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 12)

  test "immatriculation et VIN normalises" do
    vehicle = create(:vehicle, registration_number: " ab-123-cd ", vin: "vf1abc")
    assert_equal "AB-123-CD", vehicle.registration_number
    assert_equal "VF1ABC", vehicle.vin
  end

  test "type, statut et energie hors liste refuses" do
    assert_not build(:vehicle, vehicle_type: "fusee").valid?
    assert_not build(:vehicle, status: "perdu").valid?
    assert_not build(:vehicle, fuel: "charbon").valid?
    assert_not build(:vehicle, mileage: -1).valid?
  end

  test "premier controle technique deduit de la mise en circulation" do
    car = create(:vehicle, first_registration_on: Date.new(2023, 5, 2))
    moto = create(:vehicle, vehicle_type: "moto", first_registration_on: Date.new(2023, 5, 2))
    bike = create(:vehicle, vehicle_type: "velo_electrique", first_registration_on: Date.new(2023, 5, 2))

    assert_equal Date.new(2027, 5, 2), car.next_inspection_on
    assert_equal Date.new(2028, 5, 2), moto.next_inspection_on
    assert_nil bike.next_inspection_on
  end

  test "un controle favorable pose le prochain a deux ans, une contre-visite a deux mois" do
    vehicle = create(:vehicle, first_registration_on: Date.new(2018, 1, 1))
    vehicle.vehicle_interventions.create!(occurred_on: Date.new(2026, 9, 1), kind: "controle_technique", outcome: "contre_visite")
    assert_equal Date.new(2026, 11, 1), vehicle.reload.technical_inspection_due_on

    vehicle.vehicle_interventions.create!(occurred_on: Date.new(2026, 10, 1), kind: "controle_technique", outcome: "favorable")
    assert_equal Date.new(2028, 10, 1), vehicle.reload.next_inspection_on

    # Un vieux controle consigne apres coup ne ramene pas l'echeance en arriere.
    vehicle.vehicle_interventions.create!(occurred_on: Date.new(2024, 10, 1), kind: "controle_technique", outcome: "favorable")
    assert_equal Date.new(2028, 10, 1), vehicle.reload.technical_inspection_due_on
  end

  test "deux-roues : controle tous les trois ans ; resultat ignore hors controle technique" do
    moto = create(:vehicle, vehicle_type: "moto")
    moto.vehicle_interventions.create!(occurred_on: Date.new(2026, 4, 15), kind: "controle_technique", outcome: "favorable")
    assert_equal Date.new(2029, 4, 15), moto.reload.technical_inspection_due_on

    repair = moto.vehicle_interventions.create!(occurred_on: TODAY, kind: "reparation", outcome: "favorable", title: "Chaîne")
    assert_nil repair.outcome
  end

  test "le kilometrage du vehicule suit le carnet sans jamais reculer" do
    vehicle = create(:vehicle, mileage: 50_000, mileage_on: Date.new(2026, 1, 1))
    create(:vehicle_intervention, vehicle: vehicle, mileage: 61_200, occurred_on: Date.new(2026, 9, 1))
    assert_equal [61_200, Date.new(2026, 9, 1)], vehicle.reload.slice(:mileage, :mileage_on).values

    create(:vehicle_intervention, vehicle: vehicle, mileage: 40_000, occurred_on: Date.new(2025, 1, 1))
    assert_equal 61_200, vehicle.reload.mileage
  end

  test "prochaine revision depuis le dernier entretien, au premier des deux termes" do
    vehicle = create(:vehicle, service_interval_km: 15_000, service_interval_months: 12)
    create(:vehicle_intervention, vehicle: vehicle, occurred_on: Date.new(2025, 11, 1), mileage: 60_000)
    create(:vehicle_intervention, vehicle: vehicle, occurred_on: Date.new(2026, 2, 1), kind: "pneus", title: "Pneus", mileage: 62_000)
    vehicle.reload

    assert_equal Date.new(2026, 11, 1), vehicle.next_service_on
    assert_equal 75_000, vehicle.next_service_mileage
    assert_equal 13_000, vehicle.service_mileage_left
    assert_equal "due_soon", vehicle.service_status(TODAY)

    vehicle.update!(mileage: 75_500)
    assert_equal "overdue", vehicle.service_status(TODAY)

    vehicle.update!(mileage: 62_000)
    assert_equal "ok", vehicle.service_status(Date.new(2026, 1, 1))
  end

  test "un vehicule vendu n'a plus d'echeance" do
    vehicle = create(:vehicle, status: "vendu", technical_inspection_due_on: TODAY, service_interval_months: 12)
    create(:vehicle_intervention, vehicle: vehicle)
    vehicle.reload
    assert_nil vehicle.next_inspection_on
    assert_nil vehicle.next_service_on
    assert_nil vehicle.inspection_status(TODAY)
  end

  test "un intitule vide prend le nom de la nature" do
    intervention = create(:vehicle_intervention, kind: "pneus", title: "")
    assert_equal "Pneus", intervention.title
  end

  test "supprimer le vehicule garde ses documents et ses contrats" do
    vehicle = create(:vehicle)
    document = Document.new(name: "Carte grise", domain: "vehicles", category: "registration", vehicle: vehicle)
    document.file.attach(io: StringIO.new("%PDF-1.4"), filename: "cg.pdf", content_type: "application/pdf")
    document.save!
    item = create(:insured_item, kind: "vehicule", name: "Clio", vehicle: vehicle)
    create(:vehicle_intervention, vehicle: vehicle)

    vehicle.destroy!

    assert_nil document.reload.vehicle_id
    assert_nil item.reload.vehicle_id
    assert_equal 0, VehicleIntervention.count
  end
end
