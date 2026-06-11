class CvFormation < ApplicationRecord
  CATEGORIES = %w[diplome memoire seminaire certification autre].freeze
  CURRENT_YEAR = Time.current.year

  validates :title, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :start_year, numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 1 }, allow_nil: true
  validates :end_year,   numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 10 }, allow_nil: true

  scope :ordered, -> { order(Arel.sql("end_year IS NULL DESC, end_year DESC, start_year DESC, position ASC")) }
end
