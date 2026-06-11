# == Schema Information
#
# Table name: quotes
#
#  id                   :bigint           not null, primary key
#  client_address_line1 :string
#  client_address_line2 :string
#  client_city          :string
#  client_country       :string           default("France")
#  client_email         :string
#  client_name          :string           not null
#  client_phone         :string
#  client_postal_code   :string
#  client_siret         :string
#  client_vat_number    :string
#  conditions           :text
#  issue_date           :date             not null
#  notes                :text
#  number               :string           not null
#  status               :string           default("pending"), not null
#  subject              :string
#  total_ht             :decimal(10, 2)   default(0.0)
#  total_ttc            :decimal(10, 2)   default(0.0)
#  total_tva            :decimal(10, 2)   default(0.0)
#  tva_rate             :decimal(5, 2)    default(20.0)
#  validity_date        :date
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  company_id           :bigint           not null
#
# Indexes
#
#  index_quotes_on_company_id             (company_id)
#  index_quotes_on_company_id_and_status  (company_id,status)
#  index_quotes_on_number                 (number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (company_id => companies.id)
#
class Quote < ApplicationRecord
  belongs_to :company
  has_many :quote_items, dependent: :destroy
  has_many :invoices

  accepts_nested_attributes_for :quote_items, allow_destroy: true

  STATUSES = %w[pending accepted refused].freeze

  validates :number, presence: true, uniqueness: true
  validates :client_name, presence: true
  validates :issue_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :tva_rate, numericality: { greater_than_or_equal_to: 0 }

  before_validation :assign_number, on: :create

  scope :ordered, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending") }

  def recalculate_totals!
    self.total_ht = quote_items.sum(:total_ht)
    self.total_tva = (total_ht * tva_rate / 100).round(2)
    self.total_ttc = total_ht + total_tva
    save!
  end

  def accept!
    update!(status: "accepted")
  end

  def refuse!
    update!(status: "refused")
  end

  private

  def assign_number
    return if number.present?

    year = Date.current.year
    last_quote = Quote.where("number LIKE ?", "DEV-#{year}-%").order(:number).last
    seq = last_quote ? last_quote.number.split("-").last.to_i + 1 : 1
    self.number = "DEV-#{year}-#{seq.to_s.rjust(3, '0')}"
  end
end
