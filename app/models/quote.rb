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
