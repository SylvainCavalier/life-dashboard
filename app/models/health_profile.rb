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
#  medical_history           :text
#  social_security_number    :string
#  specialists               :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class HealthProfile < ApplicationRecord
  # Chiffrement des donnees sensibles
  encrypts :social_security_number
  encrypts :health_insurance_number

  BLOOD_TYPES = %w[A+ A- B+ B- AB+ AB- O+ O-].freeze

  validates :blood_type, inclusion: { in: BLOOD_TYPES }, allow_blank: true
end
