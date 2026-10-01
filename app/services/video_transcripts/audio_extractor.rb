require "open3"

module VideoTranscripts
  # Extrait la piste son d'une video avant de l'envoyer a Voxtral : mp3 mono 16 kHz a
  # 48 kbit/s, soit ~20 Mo par heure, contre des centaines de Mo pour la video. La voix
  # n'y perd rien (Voxtral travaille en 16 kHz). Sans ffmpeg (Heroku sans buildpack),
  # le fichier part tel quel : Voxtral accepte aussi une video mp4 (verifie le 23/09/2026).
  class AudioExtractor
    class Error < StandardError; end

    CONTENT_TYPE = "audio/mpeg".freeze

    # On lance reellement le binaire : sa seule presence dans le PATH ne prouve pas qu'il
    # fonctionne (meme raisonnement que VideoDownloads::YtDlpService.missing_binaries).
    def self.available?
      VideoDownloads::YtDlpService.runs?("ffmpeg", "-version")
    end

    # yield(fichier mp3 ouvert), supprime a la sortie du bloc.
    def self.extract(input_path)
      Tempfile.create(["video-transcript-audio", ".mp3"], binmode: true) do |output|
        _, stderr, status = Open3.capture3(
          "ffmpeg", "-y", "-loglevel", "error", "-i", input_path.to_s,
          "-vn", "-ac", "1", "-ar", "16000", "-c:a", "libmp3lame", "-b:a", "48k", output.path
        )
        raise Error, readable(stderr) unless status.success?

        output.rewind
        yield output
      end
    end

    def self.readable(stderr)
      return "La video ne contient pas de piste son : rien a transcrire" if stderr.match?(/does not contain any stream|matches no streams/i)

      "Extraction de l'audio en echec (ffmpeg) : #{stderr.strip.truncate(300)}"
    end
  end
end
