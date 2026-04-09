class Project < ApplicationRecord
  STATUSES = %w[en_cours en_attente termine abandonne].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, numericality: { in: 0..5 }, allow_nil: true
  validates :progress, numericality: { in: 0..100 }, allow_nil: true

  scope :ordered, -> { order(priority: :desc, name: :asc) }
end
