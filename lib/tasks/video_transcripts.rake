# Points d'entree scriptables de l'outil Videos (utilises par Alfred) : transcription et
# resume d'une video deja rangee par le Downloader.
#
# Arguments : DOWNLOAD_ID (id du VideoDownload), LANGUAGE (auto | fr | en | ru | uk,
# defaut auto), TITLE (defaut : titre du telechargement), DOCUMENTS=1 pour ranger le PDF
# dans les documents (domaine "transcriptions") une fois termine (run_now uniquement).
namespace :video_transcripts do
  build_from_env = lambda do
    id = ENV["DOWNLOAD_ID"].presence || abort("DOWNLOAD_ID manquant : rake video_transcripts:run DOWNLOAD_ID=12")
    download = VideoDownload.find_by(id: id) || abort("Telechargement ##{id} introuvable")
    transcript = VideoTranscript.build_from_download(download, language: ENV.fetch("LANGUAGE", "auto"))
    transcript.title = ENV["TITLE"] if ENV["TITLE"].present?
    transcript
  end

  desc "Enfile la transcription d'un telechargement (GoodJob) : rake video_transcripts:run DOWNLOAD_ID=12 [LANGUAGE=ru] [TITLE=...]"
  task run: :environment do
    transcript = build_from_env.call
    transcript.save!
    transcript.process!
    puts "Transcription ##{transcript.id} enfilee (#{transcript.language_label})"
  rescue ActiveRecord::RecordInvalid => e
    abort "Invalide : #{e.record.errors.full_messages.to_sentence}"
  end

  desc "Transcrit immediatement, sans GoodJob : rake video_transcripts:run_now DOWNLOAD_ID=12 [LANGUAGE=ru] [DOCUMENTS=1]"
  task run_now: :environment do
    transcript = build_from_env.call
    transcript.save!
    transcript.update!(requested_at: Time.current)
    VideoTranscriptJob.perform_now(transcript.id)
    transcript.reload
    abort "Echec : #{transcript.error}" unless transcript.done?

    puts "Transcription ##{transcript.id} terminee : #{transcript.title} (#{transcript.turns.size} tours de parole)"
    puts transcript.summary["overview"] if transcript.summary.present?
    if ENV["DOCUMENTS"] == "1"
      document = transcript.save_to_documents!
      puts "PDF range dans les documents : Document ##{document.id}"
    end
  rescue ActiveRecord::RecordInvalid => e
    abort "Invalide : #{e.record.errors.full_messages.to_sentence}"
  end
end
