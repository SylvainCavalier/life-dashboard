# == Schema Information
#
# Table name: cv_skills
#
#  id         :bigint           not null, primary key
#  category   :string           default("autre"), not null
#  level      :string
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_cv_skills_on_category  (category)
#  index_cv_skills_on_position  (position)
#
class CvSkill < ApplicationRecord
  CATEGORIES = %w[informatique langue permis secourisme autre].freeze

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(position: :asc, category: :asc, name: :asc) }
end
