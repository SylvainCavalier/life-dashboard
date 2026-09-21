# Points d'entree scriptables du module Downloader (utilises par Alfred).
#
# Arguments communs : URL, FORMAT (mp4 | mp3, defaut mp4), QUALITY (original | 720p,
# defaut original, ignore en mp3), STORAGE (local | cloud, defaut local comme dans l'interface),
# FOLDER (nom d'un dossier existant, cloud uniquement).
# Une URL contient souvent des caracteres que zsh interprete : on passe donc par
# des variables d'environnement plutot que par la syntaxe rake[...].
namespace :downloader do
  attributes_from_env = lambda do
    url = ENV["URL"].presence || abort("URL manquante : rake downloader:fetch URL=https://...")
    format = ENV.fetch("FORMAT", "mp4")
    folder = ENV["FOLDER"].presence && (
      VideoFolder.find_by("lower(name) = ?", ENV["FOLDER"].downcase) || abort("Dossier inconnu : #{ENV['FOLDER']}")
    )

    {
      url: url,
      format: format,
      quality: format == "mp4" ? ENV.fetch("QUALITY", "original") : nil,
      storage: ENV.fetch("STORAGE", "local"),
      video_folder: folder
    }
  end

  desc "Enfile un telechargement (GoodJob) : rake downloader:fetch URL=... [FORMAT=mp3] [QUALITY=720p] [STORAGE=cloud] [FOLDER=nom]"
  task fetch: :environment do
    download = VideoDownload.enqueue!(attributes_from_env.call)
    puts "Telechargement ##{download.id} enfile (#{download.format}, #{download.storage})"
  rescue ActiveRecord::RecordInvalid => e
    abort "Invalide : #{e.record.errors.full_messages.to_sentence}"
  end

  desc "Telecharge immediatement, sans GoodJob : rake downloader:fetch_now URL=... (memes options)"
  task fetch_now: :environment do
    download = VideoDownload.create!(attributes_from_env.call.merge(status: "pending"))
    VideoDownloadJob.perform_now(download.id)
    download.reload
    abort "Echec : #{download.error_message}" unless download.completed?

    location = download.cloud? ? "bucket OVH (#{download.file.key})" : download.local_filepath
    puts "Telechargement ##{download.id} termine : #{download.title} -> #{location}"
    puts "Source : #{download.citation}"
  rescue ActiveRecord::RecordInvalid => e
    abort "Invalide : #{e.record.errors.full_messages.to_sentence}"
  end

  # YouTube change regulierement : un yt-dlp de quelques mois finit par echouer.
  # Le binaire officiel autonome (celui de ~/.local/bin) sait se mettre a jour
  # lui-meme ; une installation Homebrew ou pip refuse `-U` et indique quoi faire.
  desc "Met a jour yt-dlp (yt-dlp -U) puis affiche la version"
  task update: :environment do
    binary = VideoDownloads::YtDlpService.binary
    system(binary, "-U") || abort("Mise a jour impossible avec `#{binary} -U` (voir le message ci-dessus)")
    system(binary, "--version")
  end

  desc "Verifie la presence de yt-dlp et ffmpeg"
  task check: :environment do
    missing = VideoDownloads::YtDlpService.missing_binaries
    abort "Binaires absents ou inutilisables : #{missing.join(', ')}" if missing.any?

    puts "yt-dlp et ffmpeg sont operationnels"
  end
end
