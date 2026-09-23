require "net/http"

module Transcription
  # Voxtral (`/v1/audio/transcriptions`, compatible OpenAI). Accepte tel quel le
  # webm/opus de Chrome et le mp4/aac de Safari iOS : aucune conversion ffmpeg.
  # Faraday n'ayant pas le middleware multipart dans le bundle, on passe par Net::HTTP
  # (qui envoie le fichier en flux, sans le charger en memoire).
  class MistralTranscriber
    DEFAULT_MODEL = "voxtral-mini-latest".freeze
    ENDPOINT = URI("https://api.mistral.ai/v1/audio/transcriptions").freeze
    # Dictee : sous le delai du routeur Heroku (30 s), la requete du navigateur est synchrone.
    DICTATION_TIMEOUT = 25
    # Reunion (dans un job) : une heure d'audio se transcrit en ~25 s (mesure du 23/09/2026),
    # large marge pour trois heures.
    MEETING_TIMEOUT = 600

    attr_reader :model

    def initialize(api_key: ENV["MISTRAL_API_KEY"], model: ENV.fetch("TRANSCRIPTION_MODEL", DEFAULT_MODEL))
      @api_key = api_key
      @model = model
    end

    # Dictee : texte seul.
    def transcribe(io:, filename:, content_type:, language: "fr")
      request(io:, filename:, content_type:, fields: [["language", language]], timeout: DICTATION_TIMEOUT)["text"].to_s.strip
    end

    # Reunion : segments horodates avec l'intervenant (diarisation). Voxtral garde la
    # meme numerotation des voix sur tout l'enregistrement, meme long (decoupage interne).
    # Renvoie { segments: [{ "speaker", "start", "end", "text" }], duration: secondes }.
    def transcribe_with_speakers(io:, filename:, content_type:, language: "fr")
      body = request(io:, filename:, content_type:, timeout: MEETING_TIMEOUT, fields: [
        ["language", language], ["diarize", "true"], ["timestamp_granularities", "segment"]
      ])
      segments = Array(body["segments"]).filter_map do |segment|
        text = segment["text"].to_s.strip
        next if text.empty?

        { "speaker" => segment["speaker_id"].presence || "speaker_1", "start" => segment["start"].to_f.round(1),
          "end" => segment["end"].to_f.round(1), "text" => text }
      end
      duration = body.dig("usage", "prompt_audio_seconds") || segments.last&.dig("end")
      { segments: segments, duration: duration&.round }
    end

    private

    def request(io:, filename:, content_type:, fields:, timeout:)
      raise NotConfigured, "MISTRAL_API_KEY manquante" if @api_key.blank?

      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{@api_key}"
      request.set_form(
        [["model", @model], *fields, ["file", io, { filename: filename, content_type: content_type }]],
        "multipart/form-data"
      )

      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: timeout) do |http|
        http.request(request)
      end
      raise Error, "Voxtral #{response.code} : #{response.body.to_s.truncate(300)}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
      raise Error, "Voxtral injoignable (#{e.class.name.demodulize})"
    rescue JSON::ParserError
      raise Error, "Reponse de Voxtral illisible"
    end
  end
end
