# == Schema Information
#
# Table name: insured_items
#
#  id           :bigint           not null, primary key
#  description  :text
#  kind         :string           default("autre"), not null
#  name         :string           not null
#  value        :decimal(12, 2)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  insurance_id :bigint           not null
#  property_id  :bigint
#
# Indexes
#
#  index_insured_items_on_insurance_id  (insurance_id)
#  index_insured_items_on_property_id   (property_id)
#
# Foreign Keys
#
#  fk_rails_...  (insurance_id => insurances.id)
#  fk_rails_...  (property_id => properties.id) ON DELETE => nullify
#
# Ce que couvre un contrat : un logement (lie si possible a un bien de la page
# Immobilier), un vehicule, une personne, un animal, un objet de valeur.
class InsuredItem < ApplicationRecord
  KINDS = %w[logement vehicule personne animal objet autre].freeze

  belongs_to :insurance
  belongs_to :property, optional: true

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def api_attributes
    attributes.symbolize_keys.slice(:id, :insurance_id, :property_id, :name, :kind, :description, :value)
              .merge(property_name: property&.name)
  end
end
