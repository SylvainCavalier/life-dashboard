# == Schema Information
#
# Table name: insurance_imports
#
#  id          :bigint           not null, primary key
#  draft       :jsonb
#  error       :text
#  extractor   :string
#  finished_at :datetime
#  status      :string           default("pending"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

# Creation d'une assurance a partir de son contrat (PDF ou photo). Le fichier arrive en
# direct upload, InsuranceImportJob en extrait le texte (pdf-reader, OCR Mistral pour un
# scan) puis Mistral le range dans `draft`. Rien n'est cree tant que Sylvain n'a pas
# relu : `confirm!` cree le contrat, ses garanties, ses biens assures et le Document
# du fichier, puis l'import disparait. La table fait foi pour l'etat du job (sondage).
class InsuranceImport < ApplicationRecord
  STATUSES = %w[pending running done failed].freeze
  ACCEPTED_TYPES = %w[application/pdf image/jpeg image/png image/webp].freeze
  MAX_BYTES = 45.megabytes # limite de l'OCR Mistral
  # Import abandonne (onglet ferme avant validation) : purge au suivant.
  STALE_AFTER = 1.day

  has_one_attached :file

  validates :status, inclusion: { in: STATUSES }
  validate :acceptable_file

  scope :stale, -> { where(created_at: ...STALE_AFTER.ago) }

  def self.purge_stale!
    stale.find_each(&:destroy)
  end

  def in_progress?
    status.in?(%w[pending running])
  end

  def start!
    InsuranceImportJob.perform_later(id)
  end

  # `insurance` : attributs d'Insurance ; `coverages` / `items` : listes d'attributs ;
  # `document` : { name:, category: } du Document cree avec le fichier.
  def confirm!(insurance:, coverages: [], items: [], document: {})
    raise ActiveRecord::RecordInvalid, self unless file.attached?

    transaction do
      record = Insurance.create!(insurance)
      Array(coverages).each_with_index { |attrs, index| record.insurance_coverages.create!(attrs.merge(position: index)) }
      Array(items).each { |attrs| record.insured_items.create!(attrs) }
      record.documents.create!(
        domain: "insurance",
        name: document[:name].presence || record.name,
        category: document[:category].presence_in(Document::CATEGORIES["insurance"]) || "other",
        document_date: record.start_date,
        file: file.blob
      )
      # Le blob passe au Document : detacher sans purger avant de supprimer l'import.
      file.detach
      destroy!
      record
    end
  end

  def api_attributes
    {
      id: id,
      status: status,
      in_progress: in_progress?,
      draft: draft,
      extractor: extractor,
      error: error,
      file_name: file.attached? ? file.filename.to_s : nil
    }
  end

  private

  def acceptable_file
    return errors.add(:file, "manquant") unless file.attached?

    errors.add(:file, "doit etre un PDF ou une image (JPEG, PNG, WebP)") unless file.content_type.in?(ACCEPTED_TYPES)
    errors.add(:file, "trop lourd (#{MAX_BYTES / 1.megabyte} Mo max)") if file.byte_size > MAX_BYTES
  end
end
