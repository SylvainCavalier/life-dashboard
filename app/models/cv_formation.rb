# == Schema Information
#
# Table name: cv_formations
#
#  id          :bigint           not null, primary key
#  category    :string           default("diplome"), not null
#  description :text
#  end_year    :integer
#  institution :string
#  location    :string
#  position    :integer          default(0), not null
#  start_year  :integer
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_cv_formations_on_category    (category)
#  index_cv_formations_on_position    (position)
#  index_cv_formations_on_start_year  (start_year)
#
class CvFormation < ApplicationRecord
  CATEGORIES = %w[diplome memoire seminaire certification autre].freeze
  CURRENT_YEAR = Time.current.year

  validates :title, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :start_year, numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 1 }, allow_nil: true
  validates :end_year,   numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 10 }, allow_nil: true

  scope :ordered, -> { order(Arel.sql("end_year IS NULL DESC, end_year DESC, start_year DESC, position ASC")) }
end
