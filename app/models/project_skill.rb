# Competence a acquerir pour mener un projet a bien (ex. Blender pour un jeu video).
# == Schema Information
#
# Table name: project_skills
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  status     :string           default("a_apprendre"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#
# Indexes
#
#  index_project_skills_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class ProjectSkill < ApplicationRecord
  STATUSES = %w[a_apprendre en_cours acquise].freeze

  belongs_to :project

  before_create :assign_position

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  def acquired?
    status == "acquise"
  end

  def api_attributes
    {
      id: id,
      project_id: project_id,
      name: name,
      status: status,
      position: position,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def assign_position
    return unless position.zero?

    self.position = (project.project_skills.maximum(:position) || -1) + 1
  end
end
