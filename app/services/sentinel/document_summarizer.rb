# Résumé IA d'un document. Le prompt est générique ; le rôle, l'échelle
# d'importance et les catégories viennent du domaine. Pur (aucune écriture en
# base) : SentinelWeekJob l'appelle depuis plusieurs fils puis enregistre
# lui-même le résultat.
#
# Renvoie les attributs de résumé à poser sur le SentinelDocument.
module Sentinel
  class DocumentSummarizer
    MAX_CONTENT_CHARS = 15_000

    def initialize(document, domain:, llm: Sentinel::Llm.new)
      @document = document
      @domain = domain
      @llm = llm
    end

    def call
      result = @llm.call(model: Sentinel::Llm.summary_model, instructions: instructions, input: input,
                         schema: Sentinel::DocumentSummarySchema)
      content = result[:content]

      {
        display_title: content["display_title"].presence&.truncate(300),
        tldr: content["tldr"],
        key_points: Array(content["key_points"]).first(6),
        importance: content["importance"].to_s.presence_in(SentinelDocument::IMPORTANCES),
        # Garde-fou : seuls les slugs du domaine sont conservés, le modèle n'en crée pas.
        categories: Array(content["categories"]).map(&:to_s).select { |slug| @domain.categories.key?(slug) }.first(3),
        summary_model: result[:model],
        summarized_at: Time.current
      }
    end

    private

    def instructions
      <<~TEXT
        #{@domain.summary_persona}

        Produis un résumé structuré, factuel, en français.

        Échelle du champ "importance" :
        #{@domain.importance_scale}

        Le champ "categories" contient 1 à 3 slugs choisis EXCLUSIVEMENT dans cette liste (slug : libellé). Si rien ne correspond, renvoie un tableau vide :
        #{@domain.categories.map { |slug, label| "- #{slug} : #{label}" }.join("\n")}

        Si le contenu fourni est trop pauvre pour être résumé (extrait tronqué, paywall), résume ce qui est disponible sans extrapoler et mets "importance" à "low".
      TEXT
    end

    def input
      content = @document.raw_content.to_s
      omitted = content.length - MAX_CONTENT_CHARS
      content = "#{content[0, MAX_CONTENT_CHARS]}\n[... contenu tronqué, #{omitted} caractères omis]" if omitted.positive?

      <<~TEXT
        Document à résumer :
        - Type : #{@domain.kinds.fetch(@document.kind, @document.kind)}
        - Titre : #{@document.title}
        - Source : #{@document.sentinel_source.name}
        - Date : #{@document.published_at&.to_date || 'inconnue'}
        #{@document.raw_metadata['context']}

        Contenu :
        #{content}
      TEXT
    end
  end
end
