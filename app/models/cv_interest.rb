# == Schema Information
#
# Table name: cv_interests
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  position    :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_cv_interests_on_position  (position)
#
class CvInterest < ApplicationRecord
  validates :name, presence: true

  scope :ordered, -> { order(position: :asc, name: :asc) }
end
