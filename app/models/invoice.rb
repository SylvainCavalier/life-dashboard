class Invoice < ApplicationRecord
  belongs_to :company
  belongs_to :quote, optional: true
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
