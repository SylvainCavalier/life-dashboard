# == Schema Information
#
# Table name: personal_profiles
#
#  id                             :bigint           not null, primary key
#  address_line1                  :string
#  address_line2                  :string
#  bank_name                      :string
#  bic                            :string
#  birth_city                     :string
#  birth_country                  :string
#  birth_date                     :date
#  city                           :string
#  country                        :string
#  driver_license_expiry          :date
#  driver_license_number          :string
#  email                          :string
#  emergency_contact_name         :string
#  emergency_contact_phone        :string
#  emergency_contact_relationship :string
#  employer                       :string
#  employer_address               :string
#  first_name                     :string           not null
#  gender                         :string
#  iban                           :string
#  last_name                      :string           not null
#  maiden_name                    :string
#  marital_status                 :string
#  mobile_phone                   :string
#  national_id_expiry             :date
#  national_id_number             :string
#  nationality                    :string
#  number_of_children             :integer
#  occupation                     :string
#  passport_expiry                :date
#  passport_number                :string
#  phone                          :string
#  postal_code                    :string
#  professional_email             :string
#  professional_phone             :string
#  siret_number                   :string
#  social_security_number         :string
#  spouse_name                    :string
#  state                          :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  tax_id                         :string
#
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
