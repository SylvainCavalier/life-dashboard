# Synthèse hebdomadaire d'un domaine. Le modèle ne reçoit JAMAIS les textes
# bruts, seulement les résumés individuels (TLDR + points clés) : le prompt
# reste petit quelle que soit la taille de la semaine, et la synthèse ne peut
# s'appuyer que sur ce qui a déjà été résumé et vérifié document par document.
#
# Pur : reçoit les documents, renvoie { content:, model: }.
module Sentinel
  class DigestGenerator
    # Au-delà, seuls les documents les plus importants alimentent la synthèse.
    MAX_DOCUMENTS = 80
    MAX_TOP_DOCUMENTS = 5

    def initialize(week, documents, llm: Sentinel::Llm.new)
      @week = week
      @domain = week.domain_config
      @documents = documents.sort_by(&:sort_key).first(MAX_DOCUMENTS)
      @llm = llm
    end

    def call
      result = @llm.call(model: Sentinel::Llm.digest_model, instructions: instructions, input: input,
                         schema: Sentinel::DigestSchema)
      content = result[:content]
      content["top_documents"] = filter_top_documents(content["top_documents"])
      content["documents_count"] = @documents.size

      { content: content, model: result[:model] }
    end

    private

    # Garde anti-hallucination : un document_id qui ne figure pas dans la liste
    # envoyée au modèle est écarté, tout comme un doublon.
    def filter_top_documents(entries)
      known = @documents.to_set(&:id)
      Array(entries).select { |entry| known.include?(entry["document_id"]) }
                    .uniq { |entry| entry["document_id"] }
                    .first(MAX_TOP_DOCUMENTS)
    end

    def instructions
      <<~TEXT
        #{@domain.digest_persona}

        Produis la SYNTHÈSE GÉNÉRALE de la semaine, en français.

        Règles :
        - "top_documents" : au maximum #{MAX_TOP_DOCUMENTS} entrées. Chaque "document_id" DOIT être un identifiant présent dans la liste fournie. Si la semaine est calme, mets-en moins (1 ou 2, voire aucune) plutôt que de gonfler.
        - "key_themes" : agrège ce qui se recoupe, ne répète pas les titres.
        - Reste factuel : tu ne disposes que des résumés ci-dessous, n'ajoute aucune information extérieure.
      TEXT
    end

    def input
      lines = @documents.map do |document|
        <<~TEXT
          [document_id: #{document.id}] (#{@domain.kinds.fetch(document.kind, document.kind)} · #{document.sentinel_source.name} · importance=#{document.importance || 'inconnue'} · catégories=#{document.categories.join(', ').presence || 'aucune'})
          Titre : #{document.display_title.presence || document.title}
          Résumé : #{document.tldr}
          Points clés :
          #{Array(document.key_points).first(4).map { |point| "  - #{point}" }.join("\n")}
        TEXT
      end

      <<~TEXT
        Domaine de veille : #{@domain.label}
        Période : semaine du #{@week.monday.strftime('%d/%m/%Y')} au #{@week.sunday.strftime('%d/%m/%Y')}
        Nombre de documents : #{@documents.size}

        Résumés individuels (utilise document_id pour les références de top_documents) :

        #{lines.join("\n")}
      TEXT
    end
  end
end
