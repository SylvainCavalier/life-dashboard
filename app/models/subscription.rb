class Subscription < ApplicationRecord
  BILLING_CYCLES = %w[monthly yearly].freeze
  CATEGORIES = %w[ia sport telecom streaming assurance logiciel media alimentation autre].freeze

  validates :name, presence: true
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :billing_cycle, presence: true, inclusion: { in: BILLING_CYCLES }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(end_date: nil).or(where(end_date: Date.current..)) }
end
