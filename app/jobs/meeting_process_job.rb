# Traite une reunion en trois etapes, chacune reprenable :
#   1. transcribe : Voxtral avec diarisation, sur le fichier importe ou sur les morceaux
#                   d'un enregistrement en direct (recolles partie par partie) ; l'audio
#                   est supprime des que la transcription est en base (Sylvain ne veut
#                   pas le conserver).
#   2. summarize  : Meetings::Summarizer (Claude) ; les noms d'intervenants devines
#                   ne remplacent jamais ceux que Sylvain a saisis.
#   3. render     : Meetings::ReportPdf, range dans un Document (domaine "meetings"),
#                   cree au premier passage puis remplace a chaque regeneration.
# Relancer une reunion en echec ne repaie que ce qui manque.
class MeetingProcessJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(meeting_id)
    meeting = Meeting.find(meeting_id)
    # Idempotence : une re-execution GoodJob d'un job deja traite ne relance rien.
    return unless meeting.pending?

    meeting.update!(status: "running")
    # L'audio n'existe que tant que la transcription n'est pas faite.
    transcribe(meeting) if meeting.has_audio?
    summarize(meeting) if meeting.summary.blank? && meeting.transcript.present?
    render(meeting)

    meeting.update!(status: "done", step: nil, error: nil, finished_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    Rails.logger.error "[MeetingProcessJob] reunion ##{meeting_id} en echec : #{e.class}: #{e.message}"
    meeting&.update!(status: "failed", error: readable_error(e).truncate(1000), finished_at: Time.current)
  end

  private

  def transcribe(meeting)
    meeting.advance!("transcribe")
    parts = meeting.audio_parts
    segments = []
    offset = 0.0
    duration = 0

    parts.each_with_index do |blobs, index|
      result = with_part_file(blobs) do |file, blob|
        Transcription.default.transcribe_with_speakers(io: file, filename: blob.filename.to_s, content_type: blob.content_type)
      end
      segments.concat(shift(result[:segments], offset, index, parts.size))
      part_duration = (result[:duration] || result[:segments].last&.dig("end") || 0).to_f
      offset += part_duration
      duration += part_duration
    end

    meeting.update!(transcript: segments, duration_seconds: duration.round)
    meeting.audio.purge if meeting.audio.attached?
    meeting.audio_chunks.purge if meeting.audio_chunks.attached?
  end

  # Fichier importe : lu tel quel. Enregistrement en direct : les morceaux de la partie
  # recolles dans l'ordre dans un fichier temporaire (ce sont les tranches d'un seul flux).
  def with_part_file(blobs)
    return blobs.first.open { |file| yield file, blobs.first } if blobs.one?

    Tempfile.create(["meeting-part", File.extname(blobs.first.filename.to_s)], binmode: true) do |file|
      blobs.each { |blob| blob.download { |chunk| file.write(chunk) } }
      file.flush
      file.rewind
      yield file, blobs.first
    end
  end

  # Horodatage continu d'une partie a l'autre ; voix numerotees par partie au-dela de la
  # premiere (Voxtral ne sait pas que speaker_1 de la partie 2 est celui de la partie 1).
  def shift(segments, offset, index, parts_count)
    segments.map do |segment|
      speaker = index.zero? || parts_count == 1 ? segment["speaker"] : "p#{index + 1}_#{segment['speaker']}"
      segment.merge("speaker" => speaker, "start" => (segment["start"] + offset).round(1), "end" => (segment["end"] + offset).round(1))
    end
  end

  def summarize(meeting)
    meeting.advance!("summarize")
    result = Meetings::Summarizer.new(meeting).call
    meeting.update!(summary: result[:content], summary_model: result[:model],
                    speaker_names: result[:speaker_names].merge(meeting.speaker_names.compact_blank))
  end

  def render(meeting)
    meeting.advance!("render")
    report = Meetings::ReportPdf.new(meeting)
    file = { io: StringIO.new(report.generate), filename: report.filename, content_type: "application/pdf" }
    attributes = {
      name: "Reunion - #{meeting.title}",
      document_date: meeting.held_at.in_time_zone("Europe/Paris").to_date,
      category: meeting.kind,
      # Repris dans la fiche du document (et donc dans le corpus d'Alfred).
      notes: meeting.summary["overview"].presence || "Compte rendu de reunion (transcription sans synthese)."
    }

    if meeting.document
      meeting.document.update!(attributes)
      meeting.document.file.attach(file)
    else
      document = Document.create!(attributes.merge(domain: "meetings", file: file))
      meeting.update!(document: document)
    end
  end

  def readable_error(error)
    case error
    when Anthropic::Errors::AuthenticationError then "Cle ANTHROPIC_API_KEY refusee par l'API."
    when Anthropic::Errors::RateLimitError then "API Claude saturee : relancer dans un instant."
    when Anthropic::Errors::APIConnectionError then "API Claude injoignable : relancer dans un instant."
    else error.message
    end
  end
end
