require "base64"
require "image_processing/vips"

module Alfred
  module Corpus
    # OCR Mistral (`mistral-ocr-latest`) : PDF scannes et images -> Markdown par page.
    class MistralOcr
      DEFAULT_MODEL = "mistral-ocr-latest".freeze
      BASE_URL = "https://api.mistral.ai".freeze
      MAX_BYTES = 45.megabytes # limite de l'API : 50 Mo

      def initialize(api_key: ENV["MISTRAL_API_KEY"], model: DEFAULT_MODEL)
        @api_key = api_key
        @model = model
      end

      def call(blob)
        raise "MISTRAL_API_KEY manquante" if @api_key.blank?
        raise "Fichier trop volumineux pour l'OCR (#{blob.byte_size / 1.megabyte} Mo)" if blob.byte_size > MAX_BYTES

        response = connection.post("/v1/ocr") { |req| req.body = { model: @model, document: document_for(blob) } }
        raise "Mistral OCR #{response.status} : #{response.body.to_s.truncate(300)}" unless response.success?

        Array(response.body["pages"]).map { |page| page["markdown"] }.compact_blank.join("\n\n")
      end

      private

      def document_for(blob)
        if blob.content_type.start_with?("image/")
          { type: "image_url", image_url: "data:image/jpeg;base64,#{Base64.strict_encode64(normalized_image(blob))}" }
        else
          { type: "document_url", document_url: "data:#{blob.content_type};base64,#{Base64.strict_encode64(blob.download)}" }
        end
      end

      # Mistral refuse certains JPEG pourtant valides (« could not be loaded as a valid
      # image ») : profil ICC de scanner, segments Photoshop... Reencoder en JPEG
      # depouille de ses metadonnees les fait passer, et reduit au passage le poids.
      def normalized_image(blob)
        blob.open do |file|
          ImageProcessing::Vips.source(file).autorot.convert("jpg").saver(strip: true, quality: 90).call.then do |out|
            File.binread(out.path).tap { out.close! }
          end
        end
      end

      def connection
        @connection ||= Faraday.new(url: BASE_URL) do |f|
          f.request :json
          f.response :json
          f.headers["Authorization"] = "Bearer #{@api_key}"
          f.options.timeout = 180
        end
      end
    end
  end
end
