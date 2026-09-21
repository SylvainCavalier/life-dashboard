require "open3"
require "json"

module VideoDownloads
  # Pilote le binaire `yt-dlp` : une passe de metadonnees puis le telechargement.
  # `ffmpeg` est requis pour la fusion video+audio des mp4 et l'extraction mp3.
  #
  # Rien n'est specifique a YouTube : tout site gere par yt-dlp fonctionne.
  # Valides de bout en bout : YouTube, Dailymotion, Twitter/X, Crowdbunker.
  #
  # Variables d'environnement :
  # - YT_DLP_BIN : chemin du binaire (defaut `yt-dlp`, cherche dans le PATH)
  # - YT_DLP_COOKIES_FROM_BROWSER : navigateur dont yt-dlp emprunte les cookies
  #   pour passer les controles anti-bot de YouTube. Defaut `chrome` en
  #   developpement, rien ailleurs (aucun navigateur sur un serveur).
  class YtDlpService
    class Error < StandardError; end

    # Erreurs yt-dlp frequentes -> piste en francais, ajoutee au message d'origine.
    HINTS = {
      /No video formats found/i => "aucun flux video a cette adresse (direct programme ou jamais enregistre, video retiree ?)",
      /Unsupported URL/i => "ce site n'est pas gere par yt-dlp",
      /Sign in to confirm|login required|authentication|NSFW|age.restricted|not authorized/i =>
        "le site exige d'etre connecte : verifier la session dans Chrome (cookies empruntes par yt-dlp)",
      /page needs to be reloaded|HTTP Error 403|nsig|Requested format is not available/i =>
        "extraction cassee par un changement du site : lancer `bin/rails downloader:update`",
      /Private video|Video unavailable|has been removed|does not exist/i => "video privee, supprimee ou indisponible"
    }.freeze

    Result = Struct.new(:filepath, :title, :filename, :file_size,
                        :thumbnail_url, :description, :duration,
                        :platform, :canonical_url, :uploader, :uploader_handle,
                        :uploader_url, :published_at, :view_count, keyword_init: true)

    def self.binary
      ENV.fetch("YT_DLP_BIN", "yt-dlp")
    end

    def self.cookies_from_browser
      ENV.fetch("YT_DLP_COOKIES_FROM_BROWSER") { Rails.env.development? ? "chrome" : "" }
    end

    # Binaires absents ou hors d'etat de demarrer : permet a l'interface
    # d'expliquer pourquoi le module est inutilisable (Heroku sans buildpack,
    # ffmpeg Homebrew casse par la mise a jour d'une de ses bibliotheques...)
    # au lieu d'empiler des telechargements en echec. On lance reellement le
    # binaire : sa seule presence dans le PATH ne prouve pas qu'il fonctionne.
    def self.missing_binaries
      { binary => "--version", "ffmpeg" => "-version" }.reject { |name, flag| runs?(name, flag) }.keys
    end

    def self.available?
      missing_binaries.empty?
    end

    def self.runs?(name, version_flag)
      _, status = Open3.capture2e(name, version_flag)
      status.success?
    rescue SystemCallError
      false
    end

    def initialize(url:, format:, output_dir:, quality: nil)
      @url = url
      @format = format
      @quality = quality
      @output_dir = output_dir.to_s
    end

    def call
      FileUtils.mkdir_p(@output_dir)
      metadata = fetch_metadata
      filepath = run_download
      filepath = remux_mp4(filepath) if @format == "mp4"
      Result.new(
        filepath: filepath,
        title: metadata["title"],
        filename: File.basename(filepath),
        file_size: File.size(filepath),
        thumbnail_url: metadata["thumbnail"],
        description: metadata["description"],
        duration: metadata["duration"]&.to_i,
        **source_attributes(metadata)
      )
    end

    private

    def fetch_metadata
      stdout, stderr, status = capture(self.class.binary, *cookies_args, *playlist_args,
                                       "--dump-json", "--no-warnings", "--", @url)
      raise Error, "Impossible de lire les metadonnees : #{with_hint(stderr)}" unless status.success?

      # Une ligne JSON par video : on ne garde que la premiere (cf. playlist_args).
      first_line = stdout.lines.map(&:strip).reject(&:empty?).first
      raise Error, "Aucune video trouvee a cette adresse" if first_line.nil?

      JSON.parse(first_line)
    end

    # De quoi citer la source. Les champs varient selon les sites (Crowdbunker
    # ne donne ni l'heure de publication ni l'URL de la chaine, Dailymotion pas
    # d'URL d'auteur...) : tout est optionnel.
    def source_attributes(metadata)
      {
        platform: metadata["extractor_key"],
        canonical_url: metadata["webpage_url"],
        uploader: metadata["channel"].presence || metadata["uploader"],
        uploader_handle: metadata["uploader_id"],
        uploader_url: metadata["uploader_url"].presence || metadata["channel_url"],
        published_at: published_at_from(metadata),
        view_count: metadata["view_count"]
      }
    end

    # `timestamp` (epoch, precis) quand le site le fournit, sinon `upload_date`
    # (AAAAMMJJ, ramene a minuit UTC).
    def published_at_from(metadata)
      return Time.zone.at(metadata["timestamp"]) if metadata["timestamp"].present?
      return nil if metadata["upload_date"].blank?

      Date.strptime(metadata["upload_date"].to_s, "%Y%m%d").in_time_zone("UTC")
    rescue ArgumentError, TypeError
      nil
    end

    def run_download
      output_template = File.join(@output_dir, "%(title).150B [%(id)s].%(ext)s")
      args = cookies_args + base_args + format_args + [ "-o", output_template, "--", @url ]
      stdout, stderr, status = capture(self.class.binary, *args)
      raise Error, "yt-dlp a echoue : #{with_hint(stderr.presence || stdout)}" unless status.success?

      final_path = extract_final_path(stdout)
      raise Error, "Fichier telecharge introuvable" unless final_path && File.exist?(final_path)

      final_path
    end

    # `--print after_move:filepath` : le chemin final est la derniere ligne non
    # vide de stdout. Invariant a conserver si un autre flag ecrit sur stdout.
    def base_args
      playlist_args + [ "--no-warnings", "--no-progress", "--print", "after_move:filepath" ]
    end

    # Une seule video par telechargement. `--no-playlist` ne suffit pas partout :
    # un tweet contenant plusieurs videos est une "playlist" pour yt-dlp, d'ou
    # `--playlist-items 1` (pour viser la 2e video d'un tweet, l'URL se termine
    # par /video/2 et yt-dlp ne renvoie alors que celle-la).
    def playlist_args
      [ "--no-playlist", "--playlist-items", "1" ]
    end

    def cookies_args
      browser = self.class.cookies_from_browser
      return [] if browser.blank?

      [ "--cookies-from-browser", browser ]
    end

    def format_args
      case @format
      when "mp3"
        [ "-x", "--audio-format", "mp3", "--audio-quality", "0" ]
      when "mp4"
        # Tri plutot que filtre : un filtre `height<=1080` degrade les videos
        # verticales (1080x1920 retombait en 480x854) et echoue sur les sites qui
        # n'annoncent pas la resolution. `res` porte sur la plus petite dimension.
        # H.264 + AAC d'abord : seuls codecs que les produits Adobe lisent sans
        # broncher dans un mp4 ; a defaut, yt-dlp prend ce qui existe.
        resolution = @quality == "720p" ? 720 : 1080
        [ "-f", "bv*+ba/b", "-S", "vcodec:h264,res:#{resolution},acodec:aac", "--merge-output-format", "mp4" ]
      else
        raise Error, "Format non gere : #{@format}"
      end
    end

    def extract_final_path(stdout)
      stdout.lines.map(&:strip).reject(&:empty?).last
    end

    # Le mp4 fusionne par yt-dlp se lit partout mais fait planter les produits
    # Adobe (After Effects / Premiere). Un remux en copie de flux via ffmpeg
    # produit un fichier qu'ils acceptent. Sans perte, quasi instantane.
    def remux_mp4(filepath)
      tmp_path = "#{filepath}.remux.mp4"
      _, stderr, status = capture(
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", filepath,
        "-c", "copy", "-map", "0",
        "-movflags", "+faststart",
        tmp_path
      )
      raise Error, "Remux ffmpeg en echec : #{stderr.strip}" unless status.success?

      FileUtils.mv(tmp_path, filepath)
      filepath
    end

    def with_hint(output)
      message = output.to_s.strip
      hint = HINTS.find { |pattern, _| message.match?(pattern) }&.last
      hint ? "#{message} -- Piste : #{hint}" : message
    end

    def capture(*command)
      Open3.capture3(*command)
    rescue Errno::ENOENT
      raise Error, "Binaire introuvable : #{command.first}"
    end
  end
end
