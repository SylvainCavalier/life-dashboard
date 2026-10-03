# Un fait qu'Alfred retient d'une conversation a l'autre (« Paul, sans precision,
# c'est Paul Reboh »). Toutes les memoires sont injectees dans son prompt
# (Alfred::Prompt, section « memory ») : il les a sous les yeux sans avoir a
# chercher. Alfred ne fait que les proposer (outil propose_memory, carte a
# confirmer dans le chat) ; Sylvain les relit et les corrige depuis la page Alfred.
# `subject_type` / `subject_id` : fiche du dashboard a laquelle le fait se rapporte
# (Contact#12...), facultative.
# == Schema Information
#
# Table name: alfred_memories
#
#  id           :bigint           not null, primary key
#  category     :string           default("other"), not null
#  content      :text             not null
#  subject_type :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  subject_id   :bigint
#
# Indexes
#
#  index_alfred_memories_on_category  (category)
#
class AlfredMemory < ApplicationRecord
  CATEGORIES = {
    "people" => "Personnes",
    "preferences" => "Preferences",
    "context" => "Contexte",
    "other" => "Divers"
  }.freeze
  MAX_LENGTH = 500
  # Tout part dans chaque prompt : un plafond garde le contexte leger.
  MAX_MEMORIES = 200

  # Une memoire peut dire autant qu'une reponse d'Alfred (sante, famille...).
  encrypts :content

  validates :content, presence: true, length: { maximum: MAX_LENGTH }
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :subject_type, inclusion: { in: ->(_) { Alfred::DataAccess::READABLE.keys } }, allow_nil: true
  validates :subject_id, presence: true, if: :subject_type
  validate :subject_exists, if: -> { subject_id && Alfred::DataAccess::READABLE.key?(subject_type) }
  validate :under_limit, on: :create

  before_validation :normalize

  # Ordre stable (categorie puis anciennete) : le prompt ne bouge que si une memoire change.
  scope :ordered, -> { order(:category, :id) }

  def subject_ref = subject_type && "#{subject_type}##{subject_id}"
  def category_label = CATEGORIES.fetch(category, category)

  # Ligne du prompt : l'identifiant sert a Alfred pour corriger ou oublier.
  def prompt_line
    line = "- (memoire ##{id}, #{category_label.downcase}) #{content}"
    subject_ref ? "#{line} [fiche #{subject_ref}]" : line
  end

  private

  def normalize
    self.content = content.to_s.squish
    self.subject_type = subject_type.presence
    self.subject_id = nil unless subject_type
  end

  def subject_exists
    return if subject_type.constantize.exists?(subject_id)

    errors.add(:subject_id, "aucune fiche #{subject_ref}")
  end

  def under_limit
    errors.add(:base, "#{MAX_MEMORIES} memoires au maximum : faire du tri") if AlfredMemory.count >= MAX_MEMORIES
  end
end
