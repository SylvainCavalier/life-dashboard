class CvExperience < ApplicationRecord
  CURRENT_YEAR = Time.current.year

  validates :title, :company, :start_year, presence: true
  validates :start_year, numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 1 }
  validates :end_year,   numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 10 }, allow_nil: true

  scope :ordered, -> { order(Arel.sql("end_year IS NULL DESC, end_year DESC, start_year DESC, position ASC")) }
end
