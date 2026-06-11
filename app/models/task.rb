# == Schema Information
#
# Table name: tasks
#
#  id          :bigint           not null, primary key
#  completed   :boolean          default(FALSE), not null
#  deadline    :date
#  description :string           not null
#  priority    :integer          default(3), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_tasks_on_completed  (completed)
#  index_tasks_on_priority   (priority)
#
class Task < ApplicationRecord
  validates :description, presence: true
  validates :priority, presence: true, inclusion: { in: 1..5 }

  scope :ordered, -> { order(completed: :asc, priority: :desc, created_at: :desc) }
end
