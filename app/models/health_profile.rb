# == Schema Information
#
# Table name: health_profiles
#
#  id                        :bigint           not null, primary key
#  allergies                 :text
#  ameli_url                 :string           default("https://www.ameli.fr")
#  attending_physician       :string
#  attending_physician_phone :string
#  blood_type                :string
#  current_medications       :text
#  health_insurance_name     :string
#  health_insurance_number   :string
#  health_insurance_website  :string
#  height_cm                 :integer
#  medical_history           :text
#  social_security_number    :string
#  specialists               :text
#  weight_kg                 :decimal(5, 1)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class HealthProfile < ApplicationRecord
  # Chiffrement des donnees sensibles
  encrypts :social_security_number
  encrypts :health_insurance_number

  BLOOD_TYPES = %w[A+ A- B+ B- AB+ AB- O+ O-].freeze

  validates :blood_type, inclusion: { in: BLOOD_TYPES }, allow_blank: true
  validates :height_cm, numericality: { only_integer: true, in: 50..250 }, allow_nil: true
  validates :weight_kg, numericality: { in: 20..300 }, allow_nil: true

  # Indice de masse corporelle, arrondi a une decimale
  def bmi
    return unless height_cm.present? && weight_kg.present?

    (weight_kg / ((height_cm / 100.0)**2)).round(1)
  end

  def as_json(options = {})
    super(options).merge("bmi" => bmi&.to_f)
  end
end
