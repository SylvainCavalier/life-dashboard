class QuoteItem < ApplicationRecord
  belongs_to :quote

  DISCOUNT_TYPES = %w[none percent amount].freeze

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }, allow_blank: true
  validates :discount_value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :compute_total

  private

  def compute_total
    return unless quantity && unit_price
    subtotal = (quantity.to_d * unit_price.to_d)
    subtotal = apply_discount(subtotal)
    self.total_ht = subtotal.round(2)
  end

  def apply_discount(subtotal)
    return subtotal if discount_type.blank? || discount_type == "none" || discount_value.blank? || discount_value.zero?

    case discount_type
    when "percent"
      subtotal * (1 - discount_value.to_d / 100)
    when "amount"
      [subtotal - discount_value.to_d, 0].max
    else
      subtotal
    end
  end
end
