# Textes publiés au Journal officiel (API Légifrance, PISTE) :
#   1. POST /list/loda          -> métadonnées paginées des textes de la semaine
#   2. POST /consult/lawDecree  -> texte intégral et NOR (un appel par texte)
#
# L'API n'a aucun filtre thématique : on ramène tout le JO de la semaine et
# c'est le classifieur du domaine (préfixe NOR, motifs) qui trie ensuite.
module Sentinel
  module Adapters
    class Legifrance
      NATURES = %w[LOI ORDONNANCE DECRET ARRETE].freeze
      PAGE_SIZE = 50
      MAX_RESULTS = 600

      def initialize(_source, client: nil)
        @client = client || Sentinel::Piste::Client.new(Sentinel::Piste::Client::LEGIFRANCE_PATH)
      end

      def each_document(monday:, sunday:)
        page = 1
        yielded = 0

        loop do
          payload = @client.post("/list/loda", {
                                   pageNumber: page, pageSize: PAGE_SIZE, natures: NATURES,
                                   publicationDate: { start: monday.to_s, end: sunday.to_s },
                                   sort: "PUBLICATION_DATE_DESC", legalStatus: %w[VIGUEUR VIGUEUR_DIFF]
                                 })
          results = payload["results"] || []
          break if results.empty?

          results.each do |item|
            yield normalize(item, consult(item))
            yielded += 1
            return if yielded >= MAX_RESULTS
          end

          break if page * PAGE_SIZE >= payload["totalResultNumber"].to_i

          page += 1
        end
      end

      private

      # Un texte dont la consultation échoue reste collecté avec son seul titre.
      def consult(item)
        @client.post("/consult/lawDecree", { textId: item["id"], date: item["dateDebut"].presence || Date.current.to_s })
      rescue Sentinel::Piste::Error => e
        Rails.logger.warn "[Sentinelle] Legifrance /consult/lawDecree #{item['id']} : #{e.message}"
        nil
      end

      def normalize(item, full)
        {
          external_id: item["id"].to_s,
          kind: "reform",
          title: (item["titre"].presence || "Texte #{item['id']}").truncate(500),
          url: "https://www.legifrance.gouv.fr/loda/id/#{item['cid'].presence || item['id']}",
          published_at: parse_date(item["datePublication"] || item["dateDebut"]),
          raw_content: extract_text(full),
          # Seulement ce qui sert au tri : l'arbre complet du texte pèse des centaines de Ko.
          raw_metadata: { "nor" => full&.dig("nor") || item["nor"], "nature" => item["nature"] }.compact
        }
      end

      def extract_text(full)
        return "" if full.blank?

        [full["title"], flatten_articles(full["articles"]), flatten_sections(full["sections"])]
          .compact_blank.join("\n\n").strip
      end

      def flatten_sections(sections)
        Array(sections).map do |section|
          [section["title"].presence && "## #{section['title']}", flatten_articles(section["articles"]),
           flatten_sections(section["sections"])].compact_blank.join("\n\n")
        end.compact_blank.join("\n\n")
      end

      def flatten_articles(articles)
        Array(articles).map do |article|
          body = ActionController::Base.helpers.strip_tags(article["content"].to_s).squish
          [article["num"].presence && "Article #{article['num']}", body].compact_blank.join("\n")
        end.compact_blank.join("\n\n")
      end

      def parse_date(value)
        value.present? ? Date.parse(value.to_s) : nil
      rescue Date::Error
        nil
      end
    end
  end
end
