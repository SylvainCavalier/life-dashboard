# Competence a acquerir pour mener un projet a bien (ex. Blender pour un jeu video).
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
