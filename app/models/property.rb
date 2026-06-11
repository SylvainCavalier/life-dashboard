# == Schema Information
#
# Table name: properties
#
#  id                :bigint           not null, primary key
#  address_line1     :string
#  address_line2     :string
#  bathrooms         :integer
#  bedrooms          :integer
#  city              :string
#  construction_year :integer
#  country           :string           default("France")
#  current_value     :decimal(12, 2)
#  floors            :integer
#  loan_remaining    :decimal(12, 2)
#  monthly_charges   :decimal(10, 2)
#  monthly_payment   :decimal(10, 2)
#  months_remaining  :integer
#  name              :string           not null
#  notes             :text
#  postal_code       :string
#  property_tax      :decimal(10, 2)
#  property_type     :string           not null
#  purchase_date     :date
#  purchase_price    :decimal(12, 2)
#  rental_income     :decimal(10, 2)
#  rented            :boolean          default(FALSE)
#  rooms             :integer
#  surface           :decimal(10, 2)
#  tenant_name       :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
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
