# == Schema Information
#
# Table name: video_transcripts
#
#  id                :bigint           not null, primary key
#  duration_seconds  :integer
#  error             :text
#  finished_at       :datetime
#  language          :string           default("auto"), not null
#  requested_at      :datetime
#  source_citation   :text
#  speaker_names     :jsonb            not null
#  status            :string           default("pending"), not null
#  step              :string
#  summary           :jsonb            not null
#  summary_model     :string
#  title             :string           not null
#  transcribed_at    :datetime
#  transcript        :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  document_id       :bigint
#  user_id           :bigint           not null
#  video_download_id :bigint
#
# Indexes
#
#  index_video_transcripts_on_created_at         (created_at)
#  index_video_transcripts_on_document_id        (document_id)
#  index_video_transcripts_on_user_id            (user_id)
#  index_video_transcripts_on_video_download_id  (video_download_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (video_download_id => video_downloads.id) ON DELETE => nullify
#

# Outil Videos (page Outils) : une video importee, ou deja rangee par le Downloader,
# devient une transcription par intervenant (Voxtral) et un resume (Claude). Le PDF est
# genere a la demande (telechargement) et peut etre range dans les documents (domaine
# "transcriptions"). Une video importee n'est gardee que le temps de la transcription ;
# celle du Downloader n'est jamais touchee. Voir CLAUDE.md, section « Outil Videos ».
class VideoTranscript < ApplicationRecord
  include SpeakerTranscript
  include UserOwned

  class SourceMissing < StandardError; end

  # "auto" : Voxtral detecte la langue (aucun parametre envoye).
  LANGUAGES = {
    "auto" => "Détection automatique", "fr" => "Français", "en" => "Anglais", "ru" => "Russe", "uk" => "Ukrainien"
  }.freeze
  STATUSES = %w[pending running done failed].freeze
  STEPS = %w[transcribe summarize].freeze
  # Toute video ; l'audio seul (mp3 du Downloader, m4a) se transcrit tout aussi bien.
  MEDIA_TYPES = %r{\A(video|audio)/[\w.+-]+\z}
  # Plafond du direct upload : au-dela, l'envoi depuis le navigateur devient fragile.
  MAX_VIDEO_BYTES = 2.gigabytes
  # Telechargement de la video, extraction de l'audio et transcription d'une video de
  # plusieurs heures : au-dela, le job est mort avec le dyno et la relance redevient possible.
  STUCK_AFTER = 45.minutes

  belongs_to :video_download, optional: true
  belongs_to :document, optional: true
  # Video importee depuis l'onglet (direct upload), purgee apres transcription.
  has_one_attached :video

  validates :title, presence: true
  validates :language, inclusion: { in: LANGUAGES.keys }
  validates :status, inclusion: { in: STATUSES }
  validates :step, inclusion: { in: STEPS }, allow_nil: true
  validate :video_is_acceptable, if: -> { video.attached? && attachment_changes["video"].present? }
  validate :source_is_available, on: :create
  validate :download_belongs_to_user

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  STATUSES.each do |state|
    define_method("#{state}?") { status == state }
  end

  # Transcription d'un telechargement du Downloader : titre et citation repris de la source.
  def self.build_from_download(download, language: "auto")
    new(video_download: download, user: download.user, language: language,
        title: download.title.presence || download.filename.presence || download.url,
        source_citation: download.citation)
  end

  # Point d'entree unique (API, rake) : enfile le traitement. Verrou de ligne contre le
  # double clic ; une relance reprend la ou le traitement precedent s'est arrete.
  def process!
    with_lock do
      next if in_progress? && !stuck?

      update!(status: "pending", step: nil, error: nil, requested_at: Time.current, finished_at: nil)
      VideoTranscriptJob.perform_later(id)
    end
    self
  end

  # Nouveau resume (apres avoir nomme les intervenants) : la transcription est conservee.
  def regenerate!
    update!(summary: {}, summary_model: nil) if transcribed?
    process!
  end

  def in_progress?
    (pending? || running?) && requested_at.present?
  end

  def stuck?
    in_progress? && requested_at < STUCK_AFTER.ago
  end

  def transcribed?
    transcribed_at.present?
  end

  def advance!(new_step)
    update!(step: new_step)
  end

  # Code envoye a Voxtral, nil pour la detection automatique.
  def language_code
    language == "auto" ? nil : language
  end

  def language_label
    LANGUAGES.fetch(language, language)
  end

  def source_label
    video_download_id ? "Downloader" : "Import"
  end

  # La video a transcrire est-elle encore recuperable ?
  def source_available?
    video.attached? || video_download&.file_available? || false
  end

  # Fichier source sur le disque, quelle que soit son origine :
  # yield(chemin, nom de fichier, type MIME).
  def with_source_file
    if video.attached?
      video.blob.open { |file| yield file.path, video.filename.to_s, video.content_type }
    elsif video_download&.file_available? && video_download.local?
      yield video_download.local_filepath, video_download.filename, video_download.content_type
    elsif video_download&.file_available?
      blob = video_download.file.blob
      blob.open { |file| yield file.path, blob.filename.to_s, blob.content_type }
    else
      raise SourceMissing, "Video source introuvable : importee et deja purgee, ou telechargement supprime"
    end
  end

  # Range le PDF dans les documents (domaine "transcriptions"), ou remplace celui deja
  # range : le document reste le meme, seul son fichier et son resume changent.
  def save_to_documents!
    report = VideoTranscripts::ReportPdf.new(self)
    file = { io: StringIO.new(report.generate), filename: report.filename, content_type: "application/pdf" }
    attributes = {
      name: "Transcription - #{title}".truncate(250),
      document_date: created_at.in_time_zone("Europe/Paris").to_date,
      category: "video",
      # Repris dans la fiche du document (et donc dans le corpus d'Alfred).
      notes: summary["overview"].presence || "Transcription de video (sans resume)."
    }

    transaction do
      if document
        document.update!(attributes)
        document.file.attach(file)
      else
        update!(document: Document.create!(attributes.merge(domain: "transcriptions", file: file)))
      end
    end
    document
  end

  private

  def video_is_acceptable
    content_type = video.blob.content_type.to_s
    errors.add(:video, "n'est pas une video (#{content_type.presence || 'type inconnu'})") unless MEDIA_TYPES.match?(content_type)
    errors.add(:video, "depasse #{MAX_VIDEO_BYTES / 1.gigabyte} Go") if video.blob.byte_size > MAX_VIDEO_BYTES
  end

  def source_is_available
    return if video.attached?
    return errors.add(:base, "Aucune video jointe") unless video_download
    return if video_download.file_available? && MEDIA_TYPES.match?(video_download.content_type.to_s)

    errors.add(:video_download, "n'a plus de fichier disponible")
  end

  def download_belongs_to_user
    return if video_download.nil? || video_download.user_id == user_id

    errors.add(:video_download, "est introuvable")
  end
end
