# Traite une transcription de video en deux etapes, chacune reprenable :
#   1. transcribe : piste son extraite par ffmpeg (sinon fichier envoye tel quel), puis
#                   Voxtral avec diarisation. Une video importee est supprimee des que la
#                   transcription est en base ; celle du Downloader reste ou elle est.
#   2. summarize  : VideoTranscripts::Summarizer (Claude) ; les noms d'intervenants
#                   devines ne remplacent jamais ceux que Sylvain a saisis.
# Pas d'etape PDF : il est genere a la demande (telechargement, ajout aux documents).
class VideoTranscriptJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(transcript_id)
    transcript = VideoTranscript.find(transcript_id)
    # Idempotence : une re-execution GoodJob d'un job deja traite ne relance rien.
    return unless transcript.pending?

    transcript.update!(status: "running")
    transcribe(transcript) unless transcript.transcribed?
    summarize(transcript) if transcript.summary.blank? && transcript.transcript.present?
    # Document deja range : on le tient a jour (nouveau resume, intervenants nommes).
    transcript.save_to_documents! if transcript.document

    transcript.update!(status: "done", step: nil, error: nil, finished_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    Rails.logger.error "[VideoTranscriptJob] transcription ##{transcript_id} en echec : #{e.class}: #{e.message}"
    transcript&.update!(status: "failed", error: readable_error(e).truncate(1000), finished_at: Time.current)
  end

  private

  def transcribe(transcript)
    transcript.advance!("transcribe")
    result = transcript.with_source_file do |path, filename, content_type|
      if VideoTranscripts::AudioExtractor.available?
        VideoTranscripts::AudioExtractor.extract(path) do |audio|
          voxtral(transcript, audio, "#{File.basename(filename, '.*')}.mp3", VideoTranscripts::AudioExtractor::CONTENT_TYPE)
        end
      else
        File.open(path, "rb") { |file| voxtral(transcript, file, filename, content_type) }
      end
    end

    transcript.update!(transcript: result[:segments], duration_seconds: result[:duration], transcribed_at: Time.current)
    transcript.video.purge if transcript.video.attached?
  end

  def voxtral(transcript, io, filename, content_type)
    Transcription.default.transcribe_with_speakers(io: io, filename: filename, content_type: content_type,
                                                   language: transcript.language_code)
  end

  def summarize(transcript)
    transcript.advance!("summarize")
    result = VideoTranscripts::Summarizer.new(transcript).call
    transcript.update!(summary: result[:content], summary_model: result[:model],
                       speaker_names: result[:speaker_names].merge(transcript.speaker_names.compact_blank))
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
