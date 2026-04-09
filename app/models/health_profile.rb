class HealthProfile < ApplicationRecord
  # Chiffrement des donnees sensibles
  encrypts :social_security_number
  encrypts :health_insurance_number

  BLOOD_TYPES = %w[A+ A- B+ B- AB+ AB- O+ O-].freeze

  validates :blood_type, inclusion: { in: BLOOD_TYPES }, allow_blank: true
end
