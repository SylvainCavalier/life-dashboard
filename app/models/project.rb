# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  description :text
#  github_url  :string
#  name        :string
#  notes       :text
#  priority    :integer          default(0)
#  progress    :integer          default(0)
#  site_url    :string
#  status      :string           default("en_cours")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Project < ApplicationRecord
  STATUSES = %w[en_cours en_attente termine abandonne].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, numericality: { in: 0..5 }, allow_nil: true
  validates :progress, numericality: { in: 0..100 }, allow_nil: true

  scope :ordered, -> { order(priority: :desc, name: :asc) }
end
