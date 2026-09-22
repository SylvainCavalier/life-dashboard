module Alfred
  module Tools
    class SearchCorpus < Base
      EXCERPT_CHARS = 1600

      def self.definition
        {
          name: "search_corpus",
          description: "Recherche semantique et lexicale dans tout le dashboard : fiches (contacts, notes, evenements, " \
                       "budget, factures, projets, voyages, profil...) ET contenu des documents administratifs (PDF, scans). " \
                       "A utiliser en premier des qu'il faut retrouver une information ou un document sans savoir ou il est. " \
                       "Formule la requete en langage naturel, avec les mots qui figureraient dans le texte cherche. " \
                       "Un resultat vide signifie que rien de pertinent n'existe : ne pas inventer. " \
                       "Pour filtrer, compter, trier ou lister exhaustivement, utiliser plutot query_records.",
          input_schema: {
            type: "object",
            properties: {
              query: { type: "string", description: "Ce que l'on cherche, en francais." },
              source_types: { type: "array", items: { type: "string", enum: Corpus.indexed_models },
                              description: "Restreindre a certains types d'enregistrements (optionnel)." },
              limit: { type: "integer", description: "Nombre de passages (defaut 8, max 20)." }
            },
            required: ["query"]
          }
        }
      end

      def self.step_label(input) = "Recherche : « #{input['query'].to_s.truncate(60)} »"

      def call(input)
        hits = Corpus::Search.call(query: input["query"], top_k: input["limit"] || Corpus::Search::DEFAULT_TOP_K,
                                   source_types: input["source_types"])
        return { results: [], note: "Aucun passage pertinent dans le corpus." } if hits.empty?

        results = hits.map { |hit| result_for(hit) }
        remember_sources(results)
        { results: results }
      end

      private

      def result_for(hit)
        chunk = hit.chunk
        config = Corpus.config_for(chunk.source_type)
        record = chunk.source
        result = {
          type: chunk.source_type, id: chunk.source_id, label: chunk.label,
          part: chunk.kind == "file" ? "contenu du fichier" : "fiche",
          date: chunk.source_date, score: hit.score.round(3),
          page: (record && config[:path]&.call(record)),
          excerpt: chunk.content.truncate(EXCERPT_CHARS)
        }
        result[:download] = "/api/documents/#{chunk.source_id}/download" if chunk.source_type == "Document"
        result.compact
      end

      # Sources affichees sous la reponse (tracabilite), dedoublonnees par enregistrement.
      def remember_sources(results)
        message = @context.message or return
        known = message.sources.map { |s| [s["type"], s["id"]] }
        fresh = results.map { |r| r.slice(:type, :id, :label, :page, :download, :score).stringify_keys }
                       .uniq { |s| [s["type"], s["id"]] }
                       .reject { |s| known.include?([s["type"], s["id"]]) }
        message.update!(sources: message.sources + fresh) if fresh.any?
      end
    end
  end
end
