# == Schema Information
#
# Table name: insurance_coverages
#
#  id           :bigint           not null, primary key
#  ceiling      :string
#  conditions   :text
#  deductible   :string
#  included     :boolean          default(TRUE), not null
#  name         :string           not null
#  position     :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  insurance_id :bigint           not null
#
# Indexes
#
#  index_insurance_coverages_on_insurance_id  (insurance_id)
#
# Foreign Keys
#
#  fk_rails_...  (insurance_id => insurances.id)
#
# Garantie d'un contrat d'assurance : degats des eaux, vol, bris de glace...
# `included` faux = garantie expressement exclue ou non souscrite (utile pour repondre
# « suis-je couvert contre... »). Plafond et franchise en texte libre : « 3 000 € »,
# « valeur a neuf », « 10 % des dommages, 150 € minimum ».
class InsuranceCoverage < ApplicationRecord
  belongs_to :insurance

  validates :name, presence: true

  def api_attributes
    attributes.symbolize_keys.slice(:id, :insurance_id, :name, :included, :ceiling, :deductible, :conditions, :position)
  end
end
