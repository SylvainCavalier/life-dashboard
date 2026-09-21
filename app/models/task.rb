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
#  project_id  :bigint
#
# Indexes
#
#  index_tasks_on_completed   (completed)
#  index_tasks_on_priority    (priority)
#  index_tasks_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class Task < ApplicationRecord
  # Sans projet : to-do list generale du dashboard. Avec : to-do list du projet.
  belongs_to :project, optional: true

  validates :description, presence: true
  validates :priority, presence: true, inclusion: { in: 1..5 }

  scope :general, -> { where(project_id: nil) }
  scope :ordered, -> { order(completed: :asc, priority: :desc, created_at: :desc) }
end
