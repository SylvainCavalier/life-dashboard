module Embeddings
  # mistral-embed : vecteurs de 1024 dimensions.
  class MistralProvider < BaseProvider
    DEFAULT_MODEL = "mistral-embed".freeze
    BASE_URL = "https://api.mistral.ai".freeze
    BATCH_SIZE = 32 # l'API plafonne le nombre de tokens par requete
    MAX_RETRIES = 4

    attr_reader :model

    def initialize(api_key: ENV["MISTRAL_API_KEY"], model: DEFAULT_MODEL)
      @api_key = api_key
      @model = model
    end

    def embed(texts:)
      raise "MISTRAL_API_KEY manquante" if @api_key.blank?

      Array(texts).each_slice(BATCH_SIZE).flat_map { |batch| embed_batch(batch) }
    end

    private

    def embed_batch(batch)
      attempts = 0
      begin
        response = connection.post("/v1/embeddings") { |req| req.body = { model: @model, input: batch } }
        raise RetryableError, "HTTP #{response.status}" if response.status == 429 || response.status >= 500
        raise "Mistral embeddings #{response.status} : #{response.body.to_s.truncate(300)}" unless response.success?

        # Tri defensif : ne jamais supposer que l'API conserve l'ordre.
        response.body["data"].sort_by { |row| row["index"] }.map { |row| row["embedding"] }
      rescue RetryableError, Faraday::TimeoutError, Faraday::ConnectionFailed => e
        attempts += 1
        raise "Mistral embeddings indisponible (#{e.message})" if attempts > MAX_RETRIES

        pause([0.5 * (2**(attempts - 1)), 8].min)
        retry
      end
    end

    # Couture de test.
    def pause(seconds) = sleep(seconds)

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.headers["Authorization"] = "Bearer #{@api_key}"
        f.options.timeout = 60
      end
    end

    class RetryableError < StandardError; end
  end
end
