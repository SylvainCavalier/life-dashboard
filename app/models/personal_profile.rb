class PersonalProfile < ApplicationRecord
  # Chiffrement des données sensibles
  encrypts :social_security_number
  encrypts :passport_number
  encrypts :national_id_number
  encrypts :driver_license_number
  encrypts :tax_id
  encrypts :iban
  encrypts :bic

  validates :first_name, :last_name, presence: true

  MARITAL_STATUSES = %w[single married pacs divorced widowed].freeze
  GENDERS = %w[male female other].freeze

  validates :marital_status, inclusion: { in: MARITAL_STATUSES }, allow_blank: true
  validates :gender, inclusion: { in: GENDERS }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :professional_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :number_of_children, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_address
    [address_line1, address_line2, "#{postal_code} #{city}", state, country].compact_blank.join(", ")
  end
end
