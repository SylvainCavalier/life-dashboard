# == Schema Information
#
# Table name: project_entries
#
#  id          :bigint           not null, primary key
#  body        :text
#  kind        :string           default("travail"), not null
#  occurred_on :date             not null
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  contact_id  :bigint
#  project_id  :bigint           not null
#
# Indexes
#
#  index_project_entries_on_contact_id                  (contact_id)
#  index_project_entries_on_project_id                  (project_id)
#  index_project_entries_on_project_id_and_occurred_on  (project_id,occurred_on)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (project_id => projects.id)
#

# Journal de bord d'un projet : ce qui a ete fait, decide ou appris, et quand.
# C'est la chronologie qui dit si un projet avance (rapport du matin, Alfred), la
# to-do list ne disant que ce qui reste a faire. Contact facultatif : la personne
# rencontree ou eue au telephone.
class ProjectEntry < ApplicationRecord
  KINDS = %w[travail rendez_vous echange decision jalon idee autre].freeze

  KIND_LABELS = {
    "travail" => "Travail",
    "rendez_vous" => "Rendez-vous",
    "echange" => "Échange",
    "decision" => "Décision",
    "jalon" => "Jalon",
    "idee" => "Idée",
    "autre" => "Autre"
  }.freeze

  belongs_to :project
  belongs_to :contact, optional: true

  validates :title, presence: true, length: { maximum: 200 }
  validates :occurred_on, presence: true
  validates :kind, inclusion: { in: KINDS }

  attribute :occurred_on, :date, default: -> { Date.current }

  scope :chronological, -> { order(occurred_on: :desc, created_at: :desc) }

  def kind_label = KIND_LABELS[kind]

  def api_attributes
    attributes.symbolize_keys.merge(
      kind_label: kind_label,
      contact_name: contact && [contact.first_name, contact.last_name].compact_blank.join(" ")
    )
  end
end
