# == Schema Information
#
# Table name: invoices
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
#  due_date             :date
#  issue_date           :date             not null
#  notes                :text
#  number               :string           not null
#  paid_at              :date
#  payment_method       :string
#  status               :string           default("pending"), not null
#  subject              :string
#  total_ht             :decimal(10, 2)   default(0.0)
#  total_ttc            :decimal(10, 2)   default(0.0)
#  total_tva            :decimal(10, 2)   default(0.0)
#  tva_rate             :decimal(5, 2)    default(20.0)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  client_id            :bigint
#  company_id           :bigint           not null
#  quote_id             :bigint
#
# Indexes
#
#  index_invoices_on_client_id              (client_id)
#  index_invoices_on_company_id             (company_id)
#  index_invoices_on_company_id_and_status  (company_id,status)
#  index_invoices_on_number                 (number) UNIQUE
#  index_invoices_on_quote_id               (quote_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#  fk_rails_...  (company_id => companies.id)
#  fk_rails_...  (quote_id => quotes.id)
#
class Invoice < ApplicationRecord
  belongs_to :company
  belongs_to :quote, optional: true
  belongs_to :client, optional: true
  has_many :invoice_items, dependent: :destroy

  accepts_nested_attributes_for :invoice_items, allow_destroy: true

  STATUSES = %w[pending paid].freeze
  PAYMENT_METHODS = %w[virement cheque cb especes prelevement autre].freeze

  validates :number, presence: true, uniqueness: true
  validates :client_name, presence: true
  validates :issue_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :tva_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_blank: true

  before_validation :assign_number, on: :create

  scope :ordered, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending") }

  def recalculate_totals!
    self.total_ht = invoice_items.sum(:total_ht)
    self.total_tva = (total_ht * tva_rate / 100).round(2)
    self.total_ttc = total_ht + total_tva
    save!
  end

  def mark_as_paid!(payment_method: nil)
    update!(status: "paid", paid_at: Date.current, payment_method: payment_method)
  end

  # Build an invoice from an accepted quote
  def self.from_quote(quote)
    invoice = new(
      company: quote.company,
      quote: quote,
      client_id: quote.client_id,
      client_name: quote.client_name,
      client_email: quote.client_email,
      client_phone: quote.client_phone,
      client_siret: quote.client_siret,
      client_vat_number: quote.client_vat_number,
      client_address_line1: quote.client_address_line1,
      client_address_line2: quote.client_address_line2,
      client_postal_code: quote.client_postal_code,
      client_city: quote.client_city,
      client_country: quote.client_country,
      subject: quote.subject,
      tva_rate: quote.tva_rate,
      issue_date: Date.current,
      due_date: Date.current + 30.days,
      notes: quote.notes,
      conditions: quote.conditions
    )

    quote.quote_items.order(:position).each do |qi|
      invoice.invoice_items.build(
        description: qi.description,
        quantity: qi.quantity,
        unit: qi.unit,
        unit_price: qi.unit_price,
        total_ht: qi.total_ht,
        position: qi.position,
        discount_type: qi.discount_type,
        discount_value: qi.discount_value
      )
    end

    invoice
  end

  private

  def assign_number
    return if number.present?

    year = Date.current.year
    last_invoice = Invoice.where("number LIKE ?", "FAC-#{year}-%").order(:number).last
    seq = last_invoice ? last_invoice.number.split("-").last.to_i + 1 : 1
    self.number = "FAC-#{year}-#{seq.to_s.rjust(3, '0')}"
  end
end
