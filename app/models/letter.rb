# == Schema Information
#
# Table name: letters
#
#  id                :bigint           not null, primary key
#  body              :jsonb            not null
#  footer            :text
#  include_signature :boolean          default(TRUE), not null
#  letter_date       :date
#  mention           :string
#  place             :string
#  recipient         :text
#  reference         :string
#  sender            :text
#  signatory         :string
#  subject           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  document_id       :bigint
#
# Indexes
#
#  index_letters_on_document_id  (document_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#
class Letter < ApplicationRecord
  # Courrier mis en page depuis la page Courrier (/letters). Une lettre enregistree est
  # un brouillon qu'on reprend plus tard ; le PDF et le DOCX sont generes a la demande
  # (Letters::Pdf, Letters::Docx) et `save_to_documents!` range le PDF dans la
  # bibliotheque (domaine `letters`), remplace ensuite a chaque nouvel envoi.
  belongs_to :document, optional: true

  MENTIONS = [
    "Lettre recommandée avec accusé de réception",
    "Lettre recommandée",
    "Lettre simple",
    "Remise en main propre contre décharge",
    "Envoi par courriel"
  ].freeze

  MAX_BODY_BYTES = 500.kilobytes
  MONTHS = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

  validates :subject, :mention, :reference, :place, :signatory, length: { maximum: 250 }
  validates :sender, :recipient, :footer, length: { maximum: 2_000 }
  validate :body_is_reasonable

  before_validation { self.body = Letters::Body.sanitize(body) }
  before_create :apply_profile_defaults

  # Pre-remplissage depuis « Mon profil » : formulaire de la page (GET /api/letters/defaults)
  # et lettres creees par Alfred sans expediteur, lieu ou signataire.
  def self.profile_defaults
    profile = PersonalProfile.first
    return { sender: "", place: "", signatory: "", signature_data_url: nil } unless profile

    sender = [
      profile.full_name,
      profile.address_line1,
      profile.address_line2,
      [profile.postal_code, profile.city].compact_blank.join(" "),
      (profile.country if profile.country.present? && !profile.country.match?(/\Afrance\z/i)),
      profile.mobile_phone.presence || profile.phone,
      profile.email
    ].compact_blank.join("\n")
    { sender: sender, place: profile.city.to_s, signatory: profile.full_name, signature_data_url: profile.signature_data_url }
  end

  scope :ordered, -> { order(updated_at: :desc) }

  # Texte brut du contenu, et son inverse : c'est par la qu'Alfred et les rake tasks
  # ecrivent une lettre sans manipuler le JSON de Tiptap.
  def body_text
    Letters::Body.to_text(body)
  end

  def body_text=(text)
    self.body = Letters::Body.from_text(text)
  end

  def label
    subject.presence || recipient.to_s.lines.first.to_s.strip.presence || "Courrier sans objet"
  end

  # « Créteil, le 12 octobre 2026 » (« le 1er » en debut de mois). Le front a la meme
  # regle (letterFormat.js) : l'apercu et les fichiers doivent dire la meme chose.
  def place_and_date
    date = letter_date && "le #{letter_date.day == 1 ? '1er' : letter_date.day} #{MONTHS[letter_date.month - 1]} #{letter_date.year}"
    [place.presence, date].compact.join(", ")
  end

  def signature_data
    return nil unless include_signature

    profile = PersonalProfile.first
    profile.signature.download if profile&.signature&.attached?
  rescue ActiveStorage::FileNotFoundError
    nil
  end

  def base_filename
    date = (letter_date || Date.current).iso8601
    slug = label.parameterize.first(60).presence || "courrier"
    "courrier-#{date}-#{slug}"
  end

  def to_pdf = Letters::Pdf.new(self).generate
  def to_docx = Letters::Docx.new(self).generate

  def save_to_documents!
    file = { io: StringIO.new(to_pdf), filename: "#{base_filename}.pdf", content_type: "application/pdf" }
    attributes = {
      name: "Courrier - #{label}".truncate(250),
      document_date: letter_date || Date.current,
      category: "sent",
      # Repris dans la fiche du document (et donc dans le corpus d'Alfred).
      notes: [recipient.to_s.squish.presence && "Destinataire : #{recipient.to_s.squish}", mention.presence].compact.join(" - ")
    }

    transaction do
      if document
        document.update!(attributes)
        document.file.attach(file)
      else
        update!(document: Document.create!(attributes.merge(domain: "letters", file: file)))
      end
    end
    document
  end

  private

  # Seulement les champs absents (nil) : une chaine vide envoyee par le formulaire est un
  # choix (pas d'expediteur, pas de lieu) et reste vide.
  def apply_profile_defaults
    self.letter_date ||= Date.current
    return if [sender, place, signatory].none?(&:nil?)

    defaults = self.class.profile_defaults
    self.sender = defaults[:sender] if sender.nil?
    self.place = defaults[:place] if place.nil?
    self.signatory = defaults[:signatory] if signatory.nil?
  end

  def body_is_reasonable
    errors.add(:body, "est trop volumineux") if body.to_json.bytesize > MAX_BODY_BYTES
  end
end
