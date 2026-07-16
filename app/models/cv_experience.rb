# == Schema Information
#
# Table name: cv_experiences
#
#  id          :bigint           not null, primary key
#  category    :string
#  company     :string           not null
#  description :text
#  domain      :string           default([]), is an Array
#  end_year    :integer
#  location    :string
#  position    :integer          default(0), not null
#  start_year  :integer          not null
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_cv_experiences_on_position    (position)
#  index_cv_experiences_on_start_year  (start_year)
#
class CvExperience < ApplicationRecord
  CURRENT_YEAR = Time.current.year

  CATEGORIES = %w[emploi freelance intervention media associatif].freeze
  DOMAINS    = %w[dev droit desinformation].freeze

  validates :title, :company, :start_year, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validates :start_year, numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 1 }
  validates :end_year,   numericality: { only_integer: true, greater_than_or_equal_to: 1900, less_than_or_equal_to: CURRENT_YEAR + 10 }, allow_nil: true

  scope :ordered, -> { order(Arel.sql("end_year IS NULL DESC, end_year DESC, start_year DESC, position ASC")) }
end
