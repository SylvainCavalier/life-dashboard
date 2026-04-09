class Property < ApplicationRecord
  has_many_attached :photos

  PROPERTY_TYPES = %w[appartement maison studio terrain commercial parking cave autre].freeze

  validates :name, presence: true
  validates :property_type, presence: true, inclusion: { in: PROPERTY_TYPES }
  validates :surface, numericality: { greater_than: 0 }, allow_nil: true
  validates :rooms, :bedrooms, :bathrooms, :floors, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :purchase_price, :current_value, :loan_remaining, :monthly_payment,
            :monthly_charges, :property_tax, :rental_income,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :months_remaining, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }
end
