module Alfred
  module Tools
    # Lecture integrale d'un document (PDF, scan, image) : search_corpus ne rend que
    # des extraits, insuffisants pour conclure sur un compte rendu d'analyses ou un bail.
    class ReadDocument < Base
      PAGE_CHARS = 20_000

      def self.definition
        {
          name: "read_document",
          description: "Lit le texte integral du fichier d'un document (PDF, scan passe a l'OCR, image), par tranches de " \
                       "#{PAGE_CHARS} caracteres. A utiliser des qu'un document est identifie (par search_corpus ou " \
                       "query_records) et que la reponse depend de son contenu : un extrait de recherche ne suffit pas " \
                       "pour conclure. Si `next_offset` est renvoye, le texte continue : rappeler l'outil avec cet offset.",
          input_schema: {
            type: "object",
            properties: {
              id: { type: "integer", description: "Identifiant du Document." },
              offset: { type: "integer", description: "Position de depart dans le texte (defaut 0)." }
            },
            required: ["id"]
          }
        }
      end

      def self.step_label(input)
        name = Document.where(id: input["id"]).pick(:name)
        "Lecture : #{name || "document ##{input['id']}"}"
      end

      def call(input)
        DataAccess.readable_class("Document")
        document = Document.find(input["id"])
        text, origin = text_for(document)
        offset = input["offset"].to_i.clamp(0, [text.length, 0].max)
        slice = text[offset, PAGE_CHARS].to_s
        next_offset = offset + slice.length if offset + slice.length < text.length
        @context.seen&.add(["Document", document.id])

        {
          id: document.id, name: document.name, domain: document.domain, category: document.category,
          date: document.document_date, notes: document.notes.presence,
          page: "/documents", download: "/api/documents/#{document.id}/download",
          origin: origin, total_chars: text.length, offset: offset, next_offset: next_offset,
          text: slice.presence || "(aucun texte lisible dans ce fichier)"
        }.compact
      end

      private

      # Le texte indexe d'abord (gratuit, OCR deja paye) ; a defaut, extraction a la
      # volee et indexation enfilee pour la fois suivante.
      def text_for(document)
        indexed = Corpus::Indexer.file_text(document)
        return [indexed, "index"] if indexed

        raise ArgumentError, "Le document ##{document.id} n'a pas de fichier joint." unless document.file.attached?

        text, = Corpus::TextExtractor.new.call(document.file.blob)
        Corpus.schedule(document)
        [text.to_s, "extraction directe"]
      end
    end
  end
end
