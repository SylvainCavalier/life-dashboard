class Task < ApplicationRecord
  validates :description, presence: true
  validates :priority, presence: true, inclusion: { in: 1..5 }

  scope :ordered, -> { order(completed: :asc, priority: :desc, created_at: :desc) }
end
