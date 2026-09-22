# == Schema Information
#
# Table name: video_downloads
#
#  id              :bigint           not null, primary key
#  canonical_url   :string
#  clip_end        :integer
#  clip_start      :integer
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
  validate :clip_bounds_consistent
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

  # "0:34", "1:02:03", "34" ou 34 -> secondes. nil si vide, :invalid si illisible
  # (la valeur est alors conservee telle quelle pour que la validation la refuse).
  def self.parse_timecode(value)
    return nil if value.blank?
    return value if value.is_a?(Integer)

    text = value.to_s.strip
    return :invalid unless text.match?(/\A\d+(:[0-5]?\d){0,2}\z/)

    text.split(":").map(&:to_i).reduce(0) { |total, part| total * 60 + part }
  end

  def self.format_timecode(seconds)
    return nil if seconds.nil?

    hours, rest = seconds.divmod(3600)
    minutes, secs = rest.divmod(60)
    hours.positive? ? Kernel.format("%d:%02d:%02d", hours, minutes, secs) : Kernel.format("%d:%02d", minutes, secs)
  end

  # Bornes de l'extrait : acceptent un timecode ("0:34") comme des secondes.
  %i[clip_start clip_end].each do |attribute|
    define_method("#{attribute}=") do |value|
      parsed = self.class.parse_timecode(value)
      super(parsed == :invalid ? value : parsed)
    end
  end

  # Extrait (clip_start..clip_end) plutot que la video entiere ?
  def clip?
    clip_start.present? && clip_end.present?
  end

  def clip_label
    "#{self.class.format_timecode(clip_start)} - #{self.class.format_timecode(clip_end)}" if clip?
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
      (clip? ? "extrait de #{self.class.format_timecode(clip_start)} à #{self.class.format_timecode(clip_end)}" : nil),
      citation_url
    ].compact
    consulted = completed_at ? " (consulté le #{completed_at.strftime('%d/%m/%Y')})" : ""
    parts.join(", ") + consulted
  end

  # Pour un extrait YouTube, l'URL citee ouvre la video au debut du passage.
  def citation_url
    link = canonical_url.presence || url
    return link unless clip? && platform.to_s.casecmp?("youtube") && link.include?("watch?v=")

    "#{link}&t=#{clip_start}s"
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

  # Messages sur :base : sans fichier de locale, "Clip start ..." serait illisible.
  def clip_bounds_consistent
    raw = [ clip_start_before_type_cast, clip_end_before_type_cast ]
    return if raw.all?(&:blank?)

    if raw.any? { |value| value.present? && !value.is_a?(Integer) && !value.to_s.match?(/\A\d+\z/) }
      errors.add(:base, "Timecode d'extrait illisible (formats acceptes : 0:34, 1:02:03 ou un nombre de secondes)")
    elsif clip_start.nil? || clip_end.nil?
      errors.add(:base, "Un extrait demande un debut et une fin")
    elsif clip_end <= clip_start
      errors.add(:base, "La fin de l'extrait doit etre apres son debut")
    end
  end

  def folder_only_for_cloud
    return if video_folder_id.blank?

    errors.add(:video_folder, "n'est possible que pour le stockage cloud") unless cloud?
  end

  def remove_local_files
    FileUtils.rm_rf(local_dir)
  end
end
