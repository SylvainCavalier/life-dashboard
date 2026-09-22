module Alfred
  module Corpus
    # Decoupe en fenetres glissantes : le recouvrement garde entiere, dans au moins
    # un passage, une phrase coupee par une frontiere. Tokens approximes (caracteres / 4).
    class Chunker
      DEFAULT_CHUNK_TOKENS = 600
      DEFAULT_OVERLAP_TOKENS = 100
      CHARS_PER_TOKEN = 4

      def initialize(chunk_tokens: DEFAULT_CHUNK_TOKENS, overlap_tokens: DEFAULT_OVERLAP_TOKENS)
        @chunk_chars = chunk_tokens * CHARS_PER_TOKEN
        @overlap_chars = overlap_tokens * CHARS_PER_TOKEN
      end

      def call(text)
        text = normalize(text)
        return [] if text.blank?
        return [text] if text.length <= @chunk_chars

        chunks = []
        cursor = 0
        step = @chunk_chars - @overlap_chars
        while cursor < text.length
          chunks << text[cursor, @chunk_chars]
          break if cursor + @chunk_chars >= text.length

          cursor += step
        end
        chunks
      end

      private

      def normalize(text)
        text.to_s.delete("\u0000").gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
      end
    end
  end
end
