# == Schema Information
#
# Table name: companies
#
#  id              :bigint           not null, primary key
#  activity        :string
#  address_line1   :string
#  address_line2   :string
#  capital         :decimal(12, 2)
#  city            :string
#  country         :string           default("France")
#  creation_date   :date
#  email           :string
#  employees_count :integer
#  legal_form      :string
#  name            :string           not null
#  notes           :text
#  phone           :string
#  postal_code     :string
#  rcs             :string
#  revenue         :decimal(12, 2)
#  siren           :string
#  siret           :string
#  status          :string           default("active")
#  vat_number      :string
#  website         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Company < ApplicationRecord
  has_many :quotes, dependent: :destroy
  has_many :invoices, dependent: :destroy

  LEGAL_FORMS = %w[sas sarl eurl sa sci sasu auto_entrepreneur association autre].freeze
  STATUSES = %w[active inactive en_creation radiee].freeze

  validates :name, presence: true
  validates :legal_form, inclusion: { in: LEGAL_FORMS }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }, allow_blank: true
  validates :capital, :revenue, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :employees_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }
end
