# == Schema Information
#
# Table name: document_comparisons
#
#  id          :bigint           not null, primary key
#  error       :text
#  extractors  :jsonb
#  finished_at :datetime
#  focus       :text
#  name_a      :string
#  name_b      :string
#  result      :jsonb
#  status      :string           default("pending"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_document_comparisons_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

# Onglet Comparateur de la page Outils : deux PDF arrivent en direct upload,
# DocumentComparisonJob en extrait le texte (pdf-reader, OCR Mistral pour un scan) puis
# Mistral redige la comparaison dans `result`. Les fichiers sont purges des que le job
# a fini, en succes comme en echec : seul le resultat reste. La table fait foi pour
# l'etat du job (sondage). Ouvert aux amis, chacun ne voit que ses comparaisons.
class DocumentComparison < ApplicationRecord
  include UserOwned

  STATUSES = %w[pending running done failed].freeze
  MAX_BYTES = 45.megabytes # limite de l'OCR Mistral
  MAX_FOCUS_LENGTH = 1000
  # Un job mort avec le dyno ne bloque pas l'affichage indefiniment.
  STUCK_AFTER = 15.minutes

  has_one_attached :file_a
  has_one_attached :file_b

  validates :status, inclusion: { in: STATUSES }
  validates :focus, length: { maximum: MAX_FOCUS_LENGTH }
  validate :acceptable_files, on: :create

  before_validation :remember_names, on: :create

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def in_progress?
    status.in?(%w[pending running]) && !stuck?
  end

  def stuck?
    status.in?(%w[pending running]) && created_at < STUCK_AFTER.ago
  end

  def start!
    DocumentComparisonJob.perform_later(id)
  end

  def purge_files!
    file_a.purge if file_a.attached?
    file_b.purge if file_b.attached?
  end

  def api_attributes
    {
      id: id,
      status: stuck? ? "failed" : status,
      in_progress: in_progress?,
      name_a: name_a,
      name_b: name_b,
      focus: focus,
      result: result,
      extractors: extractors,
      error: stuck? ? "Comparaison interrompue, relancez-la" : error,
      created_at: created_at,
      finished_at: finished_at
    }
  end

  private

  def remember_names
    self.name_a ||= file_a.filename.to_s if file_a.attached?
    self.name_b ||= file_b.filename.to_s if file_b.attached?
  end

  def acceptable_files
    { file_a: "premier", file_b: "second" }.each do |name, label|
      file = public_send(name)
      next errors.add(:base, "Le #{label} document est manquant") unless file.attached?

      errors.add(:base, "Le #{label} document doit etre un PDF") unless file.content_type == "application/pdf"
      errors.add(:base, "Le #{label} document est trop lourd (#{MAX_BYTES / 1.megabyte} Mo max)") if file.byte_size > MAX_BYTES
    end
  end
end
