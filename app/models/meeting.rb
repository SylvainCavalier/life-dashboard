# == Schema Information
#
# Table name: meetings
#
#  id               :bigint           not null, primary key
#  context          :text
#  duration_seconds :integer
#  error            :text
#  finished_at      :datetime
#  held_at          :datetime         not null
#  kind             :string           default("in_person"), not null
#  participants     :text
#  requested_at     :datetime
#  speaker_names    :jsonb            not null
#  status           :string           default("pending"), not null
#  step             :string
#  summary          :jsonb            not null
#  summary_model    :string
#  title            :string           not null
#  transcript       :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  document_id      :bigint
#
# Indexes
#
#  index_meetings_on_document_id  (document_id)
#  index_meetings_on_held_at      (held_at)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#
# Rapport de reunion : un enregistrement audio (presentiel ou visio) devient une
# transcription par intervenant (Voxtral), une synthese (Claude) et un PDF range
# dans les documents (domaine "meetings"). L'audio n'est garde que le temps de la
# transcription. Voir CLAUDE.md, section « Reunions ».
class Meeting < ApplicationRecord
  KINDS = %w[in_person visio].freeze
  # recording : enregistrement en direct en cours (ou interrompu), les morceaux arrivent
  # au fil de l'eau dans `audio_chunks`. Le traitement demarre a `finish!`.
  STATUSES = %w[recording pending running done failed].freeze
  STEPS = %w[transcribe summarize render].freeze
  # Chrome : webm/opus ; Safari et Dictaphone : mp4/m4a ; enregistrements Zoom : mp4.
  AUDIO_TYPES = %r{\A(audio/[\w.+-]+|video/(webm|mp4|quicktime))\z}
  MAX_AUDIO_BYTES = 500.megabytes
  MAX_CHUNK_BYTES = 20.megabytes
  # Nom d'un morceau : partie (une par session d'enregistrement) et rang dans la partie.
  CHUNK_NAME = /\Apart-(\d+)-(\d+)\./
  # Une reunion de trois heures se traite en quelques minutes ; au-dela, le job est
  # mort avec le dyno et la relance doit redevenir possible.
  STUCK_AFTER = 30.minutes

  belongs_to :document, optional: true
  # Import d'un fichier.
  has_one_attached :audio
  # Enregistrement en direct : un morceau toutes les 30 s (MediaRecorder avec timeslice).
  # Les morceaux d'une meme partie sont les tranches d'un seul flux : mis bout a bout,
  # ils reforment un fichier audio valide, sans ffmpeg. Une reprise apres interruption
  # ouvre une nouvelle partie (nouveau flux, nouvel en-tete).
  has_many_attached :audio_chunks

  validates :title, presence: true
  validates :held_at, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :step, inclusion: { in: STEPS }, allow_nil: true
  validate :audio_is_acceptable, if: -> { audio.attached? && attachment_changes["audio"].present? }
  validate :speaker_names_is_a_hash

  scope :recent, -> { order(held_at: :desc, id: :desc) }

  STATUSES.each do |state|
    define_method("#{state}?") { status == state }
  end

  # Point d'entree unique (API, rake, Alfred) : enfile le traitement. Verrou de ligne
  # contre le double clic ; une relance reprend ou le traitement precedent s'est arrete
  # (une transcription deja faite n'est pas repayee).
  def process!
    with_lock do
      next if in_progress? && !stuck?

      update!(status: "pending", step: nil, error: nil, requested_at: Time.current, finished_at: nil)
      MeetingProcessJob.perform_later(id)
    end
    self
  end

  # Nouvelle synthese et nouveau PDF (apres avoir nomme les intervenants, corrige
  # les participants...) : la transcription est conservee, seule la synthese est refaite.
  def regenerate!
    update!(summary: {}, summary_model: nil) if transcript.present?
    process!
  end

  def in_progress?
    (pending? || running?) && requested_at.present?
  end

  def stuck?
    in_progress? && requested_at < STUCK_AFTER.ago
  end

  # Fin d'un enregistrement en direct : le traitement habituel prend le relais.
  def finish!
    raise ArgumentError, "Aucun audio recu" unless audio_chunks.attached?

    process!
  end

  def has_audio?
    audio.attached? || audio_chunks.attached?
  end

  # Morceaux regroupes par partie, dans l'ordre : [[blob, blob...], [blob...]].
  def audio_parts
    return [[audio.blob]] if audio.attached?

    audio_chunks.blobs.filter_map { |blob| (m = CHUNK_NAME.match(blob.filename.to_s)) && [m[1].to_i, m[2].to_i, blob] }
                .sort_by { |part, seq, _| [part, seq] }
                .chunk_while { |a, b| a[0] == b[0] }
                .map { |group| group.map(&:last) }
  end

  # Etat de l'enregistrement pour l'interface (reprise, morceaux recus).
  def recording_stats
    names = audio_chunks.blobs.map { |blob| CHUNK_NAME.match(blob.filename.to_s) }.compact
    { chunks: names.size, parts: names.map { |m| m[1].to_i }.uniq.size,
      next_part: (names.map { |m| m[1].to_i }.max || 0) + 1, bytes: audio_chunks.blobs.sum(&:byte_size) }
  end

  def self.chunk_filename(part, seq, content_type)
    ext = { "audio/mp4" => "m4a", "audio/ogg" => "ogg" }.fetch(content_type, "webm")
    Kernel.format("part-%03d-%06d.%s", part, seq, ext)
  end

  def advance!(new_step)
    update!(step: new_step)
  end

  # Intervenants dans leur ordre d'apparition.
  def speakers
    transcript.map { |segment| segment["speaker"] }.uniq
  end

  # "speaker_2" -> nom donne par Sylvain (ou devine a la synthese), sinon "Intervenant 2".
  # Apres une reprise, les voix de la partie 2 sont numerotees a part ("p2_speaker_1") :
  # rien ne garantit que Voxtral les rattache aux memes personnes.
  def speaker_label(speaker)
    return speaker_names[speaker] if speaker_names[speaker].present?

    part, number = speaker.to_s.match(/\Ap(\d+)_speaker_(\d+)\z/)&.captures
    return "Intervenant #{number} (partie #{part})" if part

    "Intervenant #{speaker.to_s[/\d+/] || speaker}"
  end

  # Segments consecutifs du meme intervenant fusionnes en tours de parole.
  def turns
    transcript.each_with_object([]) do |segment, acc|
      if acc.last && acc.last["speaker"] == segment["speaker"]
        acc.last["text"] = "#{acc.last['text']} #{segment['text']}"
        acc.last["end"] = segment["end"]
      else
        acc << segment.slice("speaker", "start", "end", "text")
      end
    end
  end

  # Transcription lisible, une ligne par tour : "[00:12:04] Marie : ...".
  def transcript_text
    turns.map { |turn| "[#{self.class.timecode(turn['start'])}] #{speaker_label(turn['speaker'])} : #{turn['text']}" }.join("\n")
  end

  def participant_list
    participants.to_s.split(/[,;\n]/).map(&:strip).compact_blank
  end

  def kind_label
    kind == "visio" ? "Visio" : "Présentiel"
  end

  def self.timecode(seconds)
    total = seconds.to_i
    format("%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
  end

  private

  def audio_is_acceptable
    content_type = audio.blob.content_type.to_s
    errors.add(:audio, "n'est pas un fichier audio (#{content_type.presence || 'type inconnu'})") unless AUDIO_TYPES.match?(content_type)
    errors.add(:audio, "depasse #{MAX_AUDIO_BYTES / 1.megabyte} Mo") if audio.blob.byte_size > MAX_AUDIO_BYTES
  end

  def speaker_names_is_a_hash
    errors.add(:speaker_names, "doit associer un intervenant a un nom") unless speaker_names.is_a?(Hash)
  end
end
