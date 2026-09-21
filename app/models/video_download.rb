# == Schema Information
#
# Table name: video_downloads
#
#  id              :bigint           not null, primary key
#  canonical_url   :string
#  completed_at    :datetime
#  description     :text
#  duration        :integer
#  error_message   :text
#  file_size       :bigint
#  filename        :string
#  format          :string           not null
#  platform        :string
#  published_at    :datetime
#  quality         :string
#  status          :string           default("pending"), not null
#  storage         :string           not null
#  thumbnail_url   :string
#  title           :string
#  uploader        :string
#  uploader_handle :string
#  uploader_url    :string
#  url             :string           not null
#  view_count      :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  video_folder_id :bigint
#
# Indexes
#
#  index_video_downloads_on_created_at       (created_at)
#  index_video_downloads_on_status           (status)
#  index_video_downloads_on_video_folder_id  (video_folder_id)
#
# Foreign Keys
#
#  fk_rails_...  (video_folder_id => video_folders.id)
#
# La table fait foi pour l'etat du job : VideoDownloadJob met a jour `status`
# directement, l'interface sonde /api/video_downloads sans regarder GoodJob.
class VideoDownload < ApplicationRecord
  FORMATS = %w[mp4 mp3].freeze
  QUALITIES = %w[original 720p].freeze
  STORAGES = %w[local cloud].freeze
  STATUSES = %w[pending processing completed failed].freeze

  CONTENT_TYPES = {
    "mp4" => "video/mp4",
    "mp3" => "audio/mpeg"
  }.freeze

  # Racine des fichiers locaux. Attribut de classe pour que les tests, executes
  # en parallele sur des bases distinctes (donc avec des ids qui se recoupent),
  # puissent chacun pointer vers un repertoire temporaire.
  class_attribute :local_root, instance_accessor: false, default: Rails.root.join("tmp", "video_downloads")

  belongs_to :video_folder, optional: true
  has_one_attached :file

  validates :url, presence: true, format: { with: %r{\Ahttps?://}i, message: "doit etre une URL valide" }
  validates :format, inclusion: { in: FORMATS }
  validates :quality, inclusion: { in: QUALITIES }, allow_nil: true
  validates :storage, inclusion: { in: STORAGES }
  validates :status, inclusion: { in: STATUSES }
  validate :quality_required_for_mp4
  validate :folder_only_for_cloud

  before_validation :drop_quality_for_audio
  after_destroy_commit :remove_local_files

  scope :recent, -> { order(created_at: :desc) }

  STATUSES.each do |state|
    define_method("#{state}?") { status == state }
  end

  # Point d'entree unique (API, rake task, Alfred) : cree l'enregistrement et
  # enfile le job. Leve ActiveRecord::RecordInvalid si les attributs sont invalides.
  def self.enqueue!(attributes)
    create!(attributes.to_h.merge(status: "pending")).tap do |download|
      VideoDownloadJob.perform_later(download.id)
    end
  end

  def video?
    format == "mp4"
  end

  def audio?
    format == "mp3"
  end

  def cloud?
    storage == "cloud"
  end

  def local?
    storage == "local"
  end

  def content_type
    CONTENT_TYPES[format]
  end

  def self.local_dir_for(id)
    local_root.join(id.to_s)
  end

  def local_dir
    self.class.local_dir_for(id)
  end

  def local_filepath
    local_dir.join(filename).to_s if filename.present?
  end

  # Le fichier est-il encore recuperable ? Faux pour un telechargement local
  # dont le fichier a disparu du disque (redemarrage Heroku, nettoyage de tmp/).
  def file_available?
    return false unless completed?

    cloud? ? file.attached? : File.exist?(local_filepath.to_s)
  end

  # Reference prete a coller dans une description de video ou un fil :
  # « Titre », Auteur (Plateforme), publié le JJ/MM/AAAA, URL (consulté le JJ/MM/AAAA).
  # Texte destine a etre publie : c'est le seul endroit du module avec des accents.
  # La date de consultation est celle du telechargement : c'est l'etat de la
  # page a ce moment-la que le fichier archive.
  def citation
    return nil unless completed?

    author = [ uploader, (platform.present? ? "(#{platform})" : nil) ].compact.join(" ")
    parts = [
      "« #{title.presence || url} »",
      author.presence,
      (published_at ? "publié le #{published_at.strftime('%d/%m/%Y')}" : nil),
      canonical_url.presence || url
    ].compact
    consulted = completed_at ? " (consulté le #{completed_at.strftime('%d/%m/%Y')})" : ""
    parts.join(", ") + consulted
  end

  # Cle lisible dans le bucket plutot que la cle aleatoire d'Active Storage.
  # Le nom du dossier est fige au moment de l'envoi : renommer un VideoFolder
  # ne reecrit pas les cles existantes.
  def storage_key
    folder_segment = video_folder&.name&.parameterize.presence || "unsorted"
    extension = File.extname(filename.to_s)
    basename = File.basename(filename.to_s, extension).parameterize.presence || "file"
    "video_downloads/#{folder_segment}/#{id}-#{basename}#{extension}"
  end

  private

  def drop_quality_for_audio
    self.quality = nil if audio?
  end

  def quality_required_for_mp4
    return unless video?

    errors.add(:quality, "est obligatoire pour un telechargement mp4") if quality.blank?
  end

  def folder_only_for_cloud
    return if video_folder_id.blank?

    errors.add(:video_folder, "n'est possible que pour le stockage cloud") unless cloud?
  end

  def remove_local_files
    FileUtils.rm_rf(local_dir)
  end
end
