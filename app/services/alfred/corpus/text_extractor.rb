module Alfred
  module Corpus
    # Texte d'un fichier joint. PDF : pdf-reader d'abord (gratuit, local) ; s'il ne
    # ramene presque rien, le PDF est un scan et passe par l'OCR Mistral. Images : OCR.
    # Renvoie [texte, extracteur] ; l'extracteur est consigne sur AlfredIndexEntry.
    class TextExtractor
      # En dessous de ce nombre de caracteres par page, le PDF est traite comme un scan.
      MIN_CHARS_PER_PAGE = 80
      OCR_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif image/tiff].freeze

      def initialize(ocr: MistralOcr.new)
        @ocr = ocr
      end

      def call(blob)
        case blob.content_type
        when "application/pdf" then extract_pdf(blob)
        when *OCR_IMAGE_TYPES then ocr_enabled? ? [@ocr.call(blob), "mistral_ocr"] : ["", "unsupported"]
        when %r{\Atext/}, "application/json" then [blob.download.force_encoding("UTF-8").scrub, "text"]
        else ["", "unsupported"]
        end
      end

      private

      def extract_pdf(blob)
        text, pages = read_pdf(blob)
        return [text, "pdf_reader"] if text.length >= MIN_CHARS_PER_PAGE * [pages, 1].max || !ocr_enabled?

        [@ocr.call(blob), "mistral_ocr"]
      end

      def read_pdf(blob)
        blob.open do |file|
          reader = PDF::Reader.new(file)
          [reader.pages.map(&:text).join("\n\n").strip, reader.page_count]
        end
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, ArgumentError => e
        Rails.logger.warn "[Alfred::Corpus::TextExtractor] pdf-reader : #{e.class} #{e.message}"
        ["", 1]
      end

      def ocr_enabled?
        ENV.fetch("ALFRED_OCR", "1") == "1" && ENV["MISTRAL_API_KEY"].present?
      end
    end
  end
end
