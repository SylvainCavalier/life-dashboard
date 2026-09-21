# Décisions de la chambre sociale de la Cour de cassation (API Judilibre, PISTE).
# Le filtre `chamber=soc` est appliqué côté API : tout ce qui revient est dans
# le champ, la source est donc `on_topic`.
module Sentinel
  module Adapters
    class Judilibre
      BATCH_SIZE = 50
      MAX_RESULTS = 500
      PUBLICATIONS = { "b" => "Bulletin", "r" => "Rapport annuel", "l" => "Lettres de chambre",
                       "c" => "Communiqué" }.freeze

      def initialize(_source, client: nil)
        @client = client || Sentinel::Piste::Client.new(Sentinel::Piste::Client::JUDILIBRE_PATH)
      end

      def each_document(monday:, sunday:)
        page = 0
        yielded = 0

        loop do
          # /export et non /search : /search exige une requête plein texte et
          # renvoie 0 résultat avec un simple filtre de dates.
          payload = @client.get("/export", params: {
                                  date_start: monday.to_s, date_end: sunday.to_s, chamber: "soc",
                                  jurisdiction: "cc", batch: page, batch_size: BATCH_SIZE
                                })
          results = payload["results"] || []
          break if results.empty?

          results.each do |raw|
            yield normalize(raw)
            yielded += 1
            return if yielded >= MAX_RESULTS
          end

          break if (page + 1) * BATCH_SIZE >= payload["total"].to_i

          page += 1
        end
      end

      private

      def normalize(raw)
        {
          external_id: raw["id"].to_s,
          kind: "jurisprudence",
          title: title_for(raw),
          url: "https://www.courdecassation.fr/decision/#{raw['id']}",
          published_at: parse_date(raw["decision_date"]),
          raw_content: raw["text"].to_s,
          raw_metadata: {
            "number" => raw["number"], "formation" => raw["formation"], "solution" => raw["solution"],
            "publication" => raw["publication"], "ecli" => raw["ecli"], "official_summary" => raw["summary"],
            "context" => context_for(raw)
          }.compact
        }
      end

      def title_for(raw)
        parts = ["Cass. soc.", parse_date(raw["decision_date"])&.strftime("%d/%m/%Y"),
                 raw["number"].present? ? "n° #{raw['number']}" : nil, raw["solution"]]
        parts.compact_blank.join(", ")
      end

      # Indices de portée donnés au modèle : une décision publiée au Bulletin
      # ou au Rapport pèse plus qu'un arrêt d'espèce.
      def context_for(raw)
        published = Array(raw["publication"]).filter_map { |code| PUBLICATIONS[code.to_s.downcase] }
        lines = []
        lines << "Publication : #{published.join(', ')}" if published.any?
        lines << "Formation : #{raw['formation']}" if raw["formation"].present?
        lines << "Solution : #{raw['solution']}" if raw["solution"].present?
        lines << "Sommaire officiel : #{raw['summary']}" if raw["summary"].present?
        lines.join("\n").presence
      end

      def parse_date(value)
        value.present? ? Date.parse(value.to_s) : nil
      rescue Date::Error
        nil
      end
    end
  end
end
