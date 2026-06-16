# == Schema Information
#
# Table name: clients
#
#  id            :bigint           not null, primary key
#  address_line1 :string
#  address_line2 :string
#  city          :string
#  country       :string
#  email         :string
#  name          :string
#  notes         :text
#  phone         :string
#  postal_code   :string
#  siret         :string
#  vat_number    :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  company_id    :bigint           not null
#
# Indexes
#
#  index_clients_on_company_id  (company_id)
#
# Foreign Keys
#
#  fk_rails_...  (company_id => companies.id)
#
class Client < ApplicationRecord
  belongs_to :company
  has_many :quotes, dependent: :nullify
  has_many :invoices, dependent: :nullify

  validates :name, presence: true

  after_initialize :set_default_country, if: :new_record?

  scope :ordered, -> { order(:name) }

  # Maps the client fields to the denormalized client_* attributes used as a
  # snapshot on Quote/Invoice (e.g. name => client_name).
  def snapshot_attributes
    {
      client_name: name,
      client_email: email,
      client_phone: phone,
      client_siret: siret,
      client_vat_number: vat_number,
      client_address_line1: address_line1,
      client_address_line2: address_line2,
      client_postal_code: postal_code,
      client_city: city,
      client_country: country
    }
  end

  private

  def set_default_country
    self.country ||= "France"
  end
end
