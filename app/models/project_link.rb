# == Schema Information
#
# Table name: project_links
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0), not null
#  title      :string           not null
#  url        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  project_id :bigint           not null
#
# Indexes
#
#  index_project_links_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class ProjectLink < ApplicationRecord
  belongs_to :project

  before_create :assign_position

  validates :title, presence: true
  validates :url, presence: true,
                  format: { with: %r{\Ahttps?://}i, message: "doit commencer par http:// ou https://" }

  def api_attributes
    {
      id: id,
      project_id: project_id,
      title: title,
      url: url,
      position: position,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def assign_position
    return unless position.zero?

    self.position = (project.project_links.maximum(:position) || -1) + 1
  end
end
