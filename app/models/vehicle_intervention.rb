# == Schema Information
#
# Table name: vehicle_interventions
#
#  id          :bigint           not null, primary key
#  cost        :decimal(10, 2)
#  description :text
#  garage      :string
#  kind        :string           default("entretien"), not null
#  mileage     :integer
#  occurred_on :date             not null
#  outcome     :string
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  vehicle_id  :bigint           not null
#
# Indexes
#
#  index_vehicle_interventions_on_vehicle_id                  (vehicle_id)
#  index_vehicle_interventions_on_vehicle_id_and_occurred_on  (vehicle_id,occurred_on)
#
# Foreign Keys
#
#  fk_rails_...  (vehicle_id => vehicles.id)
#

# Ligne du carnet d'entretien d'un vehicule : revision, controle technique, reparation,
# pneus, carrosserie, sinistre... Enregistrer une intervention met la fiche du vehicule a
# jour : kilometrage s'il est plus eleve que le dernier releve, et pour un controle
# technique la date du prochain (periodicite du type de vehicule, ou contre-visite a
# deux mois si le resultat est defavorable). Ces deux valeurs ne font qu'avancer :
# consigner un vieux controle ne ramene pas l'echeance en arriere.
class VehicleIntervention < ApplicationRecord
  KINDS = %w[entretien controle_technique reparation pneus carrosserie sinistre autre].freeze

  KIND_LABELS = {
    "entretien" => "Entretien / révision", "controle_technique" => "Contrôle technique", "reparation" => "Réparation",
    "pneus" => "Pneus", "carrosserie" => "Carrosserie", "sinistre" => "Sinistre / accident", "autre" => "Autre"
  }.freeze

  # Resultat d'un controle technique : favorable, defavorable pour defaillances majeures
  # (contre-visite) ou critiques (circulation limitee au jour du controle).
  OUTCOMES = %w[favorable contre_visite critique].freeze

  OUTCOME_LABELS = {
    "favorable" => "Favorable", "contre_visite" => "Défavorable (contre-visite)",
    "critique" => "Défavorable (défaillance critique)"
  }.freeze

  belongs_to :vehicle

  before_validation :normalize
  after_save :apply_to_vehicle

  validates :occurred_on, :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true
  validates :mileage, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Prochain controle technique qui decoule de celui-ci (nil hors controle ou sans resultat).
  def inspection_due_on
    rule = vehicle&.inspection_rule
    return nil unless kind == "controle_technique" && outcome && rule && occurred_on

    occurred_on >> (outcome == "favorable" ? rule[:every_months] : Vehicle::RETEST_MONTHS)
  end

  def api_attributes
    attributes.symbolize_keys
              .slice(:id, :vehicle_id, :occurred_on, :kind, :title, :mileage, :cost, :garage, :outcome, :description)
              .merge(kind_label: KIND_LABELS[kind], outcome_label: OUTCOME_LABELS[outcome])
  end

  private

  def normalize
    self.outcome = nil unless kind == "controle_technique"
    self.outcome = outcome.presence
    self.title = KIND_LABELS[kind] if title.blank? && KIND_LABELS.key?(kind)
  end

  # update_columns : pas de validation du vehicule (une fiche ancienne invalide ne doit pas
  # bloquer le carnet) ; la fiche du corpus suit par le parent de VehicleIntervention.
  def apply_to_vehicle
    changes = {}
    if mileage && (vehicle.mileage.nil? || mileage > vehicle.mileage)
      changes[:mileage] = mileage
      changes[:mileage_on] = occurred_on
    end
    due = inspection_due_on
    current_due = vehicle.technical_inspection_due_on
    changes[:technical_inspection_due_on] = due if due && (current_due.nil? || due > current_due)
    vehicle.update_columns(changes.merge(updated_at: Time.current)) if changes.any?
  end
end
