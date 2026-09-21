# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  category    :string           default("developpement"), not null
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
# Indexes
#
#  index_projects_on_category  (category)
#
class Project < ApplicationRecord
  STATUSES = %w[en_cours en_attente termine abandonne].freeze
  CATEGORIES = %w[developpement musique video jeu_video sport jeu_de_role business ecriture apprentissage autre].freeze

  CATEGORY_LABELS = {
    "developpement" => "Développement",
    "musique" => "Musique",
    "video" => "Vidéo",
    "jeu_video" => "Jeu vidéo",
    "sport" => "Sport",
    "jeu_de_role" => "Jeu de rôle",
    "business" => "Business",
    "ecriture" => "Écriture",
    "apprentissage" => "Apprentissage",
    "autre" => "Autre"
  }.freeze

  has_many :project_skills, dependent: :destroy
  has_many :project_links, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }
  validates :priority, numericality: { in: 0..5 }, allow_nil: true
  validates :progress, numericality: { in: 0..100 }, allow_nil: true

  scope :ordered, -> { order(priority: :desc, name: :asc) }

  # JSON shape shared by the index (counters only) and show (full: nested records).
  def api_attributes(full: false)
    json = attributes.symbolize_keys.merge(
      category_label: CATEGORY_LABELS[category],
      skills_count: project_skills.size,
      skills_acquired_count: project_skills.count(&:acquired?),
      tasks_count: tasks.size,
      tasks_completed_count: tasks.count(&:completed),
      links_count: project_links.size,
      documents_count: documents.size
    )
    return json unless full

    json.merge(
      skills: project_skills.sort_by { |s| [s.position, s.id] }.map(&:api_attributes),
      links: project_links.sort_by { |l| [l.position, l.id] }.map(&:api_attributes)
    )
  end
end
