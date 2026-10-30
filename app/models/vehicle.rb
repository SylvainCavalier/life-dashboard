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

# Vehicule de Sylvain (page Vehicules) : caracteristiques, carnet d'entretien
# (VehicleIntervention : entretiens, controles techniques, reparations...), documents
# (Document, domaine `vehicles` : carte grise, factures, proces-verbaux) et assurances
# (InsuredItem lie par vehicle_id, comme un logement l'est par property_id).
#
# Deux echeances calculees, sans colonne a tenir a jour en dehors de la fiche :
# - controle technique : technical_inspection_due_on, posee par la saisie d'un controle
#   (VehicleIntervention#inspection_due_on) ; a defaut de controle consigne, le premier
#   se deduit de la date de premiere mise en circulation ;
# - revision : derniere intervention « entretien » + service_interval_months / _km.
class Vehicle < ApplicationRecord
  TYPES = %w[voiture moto scooter utilitaire camping_car quad velo_electrique autre].freeze

  TYPE_LABELS = {
    "voiture" => "Voiture", "moto" => "Moto", "scooter" => "Scooter", "utilitaire" => "Utilitaire",
    "camping_car" => "Camping-car", "quad" => "Quad", "velo_electrique" => "Vélo électrique", "autre" => "Autre"
  }.freeze

  STATUSES = %w[active vendu hors_service].freeze
  FUELS = %w[essence diesel hybride hybride_rechargeable electrique gpl e85 autre].freeze

  # Controle technique : age du premier controle (6 mois avant cet anniversaire de la mise
  # en circulation) puis periodicite. Deux-roues et quads : regime du 15 avril 2024.
  # Pas de controle pour un velo electrique.
  CAR_INSPECTION = { first_years: 4, every_months: 24 }.freeze
  TWO_WHEELER_INSPECTION = { first_years: 5, every_months: 36 }.freeze
  INSPECTION_RULES = {
    "voiture" => CAR_INSPECTION, "utilitaire" => CAR_INSPECTION, "camping_car" => CAR_INSPECTION,
    "moto" => TWO_WHEELER_INSPECTION, "scooter" => TWO_WHEELER_INSPECTION, "quad" => TWO_WHEELER_INSPECTION
  }.freeze
  # Contre-visite apres un controle defavorable.
  RETEST_MONTHS = 2

  # Echeance « bientot » : en orange dans la page, signalee dans le rapport du matin.
  DUE_SOON_DAYS = 30
  DUE_SOON_KM = 1000

  has_many :vehicle_interventions, -> { order(occurred_on: :desc, id: :desc) }, dependent: :destroy
  # Les documents restent dans la page Documents, et les contrats dans la page Assurances,
  # si le vehicule est supprime.
  has_many :documents, dependent: :nullify
  has_many :insured_items, dependent: :nullify
  has_many :insurances, -> { distinct }, through: :insured_items

  normalizes :registration_number, :vin, with: ->(value) { value.strip.upcase.presence }

  validates :name, presence: true
  validates :vehicle_type, presence: true, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :fuel, inclusion: { in: FUELS }, allow_blank: true
  validates :year, allow_nil: true,
                   numericality: { only_integer: true, greater_than: 1885, less_than_or_equal_to: ->(_) { Date.current.year + 1 } }
  validates :fiscal_power, :power_hp, :engine_displacement, :purchase_mileage, :mileage,
            :service_interval_km, :service_interval_months,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :purchase_price, :sale_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered, lambda {
    order(Arel.sql("CASE status WHEN 'active' THEN 0 WHEN 'hors_service' THEN 1 ELSE 2 END"), :name)
  }

  def active?
    status == "active"
  end

  def inspection_rule
    INSPECTION_RULES[vehicle_type]
  end

  # Prochain controle technique : celui pose par le dernier controle consigne, sinon le
  # premier, deduit de la mise en circulation. nil pour un vehicule vendu ou sans controle.
  def next_inspection_on
    return nil unless active? && inspection_rule

    technical_inspection_due_on || first_inspection_on
  end

  def first_inspection_on
    return nil if first_registration_on.nil? || inspection_rule.nil?
    return nil if vehicle_interventions.any? { |i| i.kind == "controle_technique" }

    first_registration_on.advance(years: inspection_rule[:first_years])
  end

  # Interventions triees de la plus recente a la plus ancienne (scope de l'association).
  def last_service
    vehicle_interventions.find { |i| i.kind == "entretien" }
  end

  def next_service_on
    return nil unless active? && service_interval_months && last_service

    last_service.occurred_on >> service_interval_months
  end

  def next_service_mileage
    return nil unless active? && service_interval_km && last_service&.mileage

    last_service.mileage + service_interval_km
  end

  # Kilometres restants avant la revision (negatif = depassee), sur le dernier releve.
  def service_mileage_left
    next_service_mileage && mileage && (next_service_mileage - mileage)
  end

  # ok / due_soon / overdue, ou nil sans echeance connue.
  def inspection_status(today = Date.current)
    due_status(next_inspection_on, today)
  end

  def service_status(today = Date.current)
    by_date = due_status(next_service_on, today)
    left = service_mileage_left
    by_km = if left.nil? then nil
            elsif left <= 0 then "overdue"
            elsif left <= DUE_SOON_KM then "due_soon"
            else "ok"
            end
    %w[overdue due_soon ok].find { |status| [by_date, by_km].include?(status) }
  end

  def total_cost
    vehicle_interventions.sum { |i| i.cost || 0 }
  end

  def api_attributes(full: false)
    json = attributes.symbolize_keys.merge(
      type_label: TYPE_LABELS[vehicle_type],
      next_inspection_on: next_inspection_on,
      inspection_status: inspection_status,
      first_inspection_computed: technical_inspection_due_on.nil? && next_inspection_on.present?,
      next_service_on: next_service_on,
      next_service_mileage: next_service_mileage,
      service_mileage_left: service_mileage_left,
      service_status: service_status,
      last_service_on: last_service&.occurred_on,
      total_cost: total_cost,
      interventions_count: vehicle_interventions.size,
      documents_count: documents.size
    )
    return json unless full

    json.merge(
      interventions: vehicle_interventions.map(&:api_attributes),
      insurances: insurances.map { |i| i.attributes.slice(*%w[id name insurer status policy_number claims_phone]) }
    )
  end

  private

  def due_status(date, today)
    return nil if date.nil?
    return "overdue" if date < today

    date <= today + DUE_SOON_DAYS ? "due_soon" : "ok"
  end
end
