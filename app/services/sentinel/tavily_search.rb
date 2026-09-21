# Recherche web Tavily d'un domaine de veille, restreinte aux noms de domaine
# de ses sources (idée de FakeNewsletter) : complète les flux RSS pour les
# sites qui n'en ont pas. Jamais de recherche « web ouvert » : elle
# contournerait la liste blanche, qui est le garde-fou éditorial.
#
# Comportements de l'API constatés le 21/09/2026, qui dictent la stratégie :
#   - une longue requête en « a OR b OR c » ne renvoie rien : requêtes courtes ;
#   - une requête en français sur des sites anglophones ne renvoie presque rien :
#     les sources sont groupées par langue, chaque langue a sa requête ;
#   - topic "news" ne couvre que les grands médias (pas Conspiracy Watch, etc.) :
#     on utilise "general" ;
#   - start_date / end_date combinés à include_domains renvoient 0 résultat, et
#     "general" ne date pas ses résultats : on borne avec time_range, puis on
#     date chaque page nous-mêmes (balises meta) et on écarte ce qui sort de la
#     semaine ou ne peut pas être daté.
module Sentinel
  class TavilySearch
    class NotConfigured < StandardError; end
    class TooOld < StandardError; end

    ENDPOINT = "https://api.tavily.com/search".freeze
    HOSTS_PER_CALL = 5
    RESULTS_PER_CALL = 15
    MAX_PER_SOURCE = 6

    def self.configured?
      ENV["TAVILY_API_KEY"].present?
    end

    # queries : { "fr" => "...", "en" => "..." }. Une source dont la langue n'a
    # pas de requête utilise la première.
    def initialize(queries:, sources:, http: Sentinel::Http, reader: Sentinel::ArticleText)
      @queries = queries
      @sources = sources.select { |source| source.host.present? }
      @http = http
      @reader = reader
    end

    # Renvoie [{ source => [attributs de document] }, erreurs]. Un groupe en
    # échec n'empêche pas les autres.
    def call(monday:, sunday:)
      raise NotConfigured, "TAVILY_API_KEY absente de l'environnement" unless self.class.configured?

      window = SentinelWeek.window(monday)
      time_range = time_range_for(monday)
      found = Hash.new { |hash, source| hash[source] = [] }
      errors = []

      groups.each do |query, group|
        search(query, group.map(&:host), time_range).each do |result|
          source = source_for(result["url"], group)
          next unless source && found[source].size < MAX_PER_SOURCE

          document = normalize(result, window)
          found[source] << document if document
        end
      rescue Sentinel::Http::Error, JSON::ParserError => e
        errors << "Recherche web (#{group.map(&:name).join(', ')}) : #{e.message}"
      end

      [found, errors]
    end

    private

    def groups
      @sources.group_by { |source| @queries[source.language] || @queries.values.first }
              .flat_map { |query, sources| sources.each_slice(HOSTS_PER_CALL).map { |slice| [query, slice] } }
    end

    # Tavily ne sait borner que « depuis N jours » : au-delà d'un mois, les
    # résultats de la semaine visée sont noyés et la recherche ne sert plus à rien.
    def time_range_for(monday)
      age = (Date.current - monday).to_i
      return "week" if age <= 7
      return "month" if age <= 31

      raise TooOld, "semaine de plus d'un mois, hors de portée de la recherche web"
    end

    def search(query, hosts, time_range)
      body = @http.post_json(
        ENDPOINT,
        { query: query, topic: "general", search_depth: "basic", max_results: RESULTS_PER_CALL,
          include_domains: hosts, time_range: time_range },
        headers: { "Authorization" => "Bearer #{ENV.fetch('TAVILY_API_KEY')}" }, timeout: 60
      )
      JSON.parse(body.dup.force_encoding(Encoding::UTF_8))["results"] || []
    end

    def source_for(url, group)
      host = URI.parse(url.to_s).host.to_s.sub(/\Awww\./, "")
      group.find { |source| host == source.host || host.end_with?(".#{source.host}") }
    rescue URI::InvalidURIError
      nil
    end

    def normalize(result, window)
      return nil if result["title"].blank? || result["url"].blank?

      page = @reader.read(result["url"])
      published_at = parse_time(result["published_date"]) || page.published_at
      # Strict : un résultat non daté pourrait être un vieil article, il polluerait la semaine.
      return nil unless published_at && window.cover?(published_at)

      {
        external_id: Sentinel::UrlNormalizer.call(result["url"]),
        kind: "article",
        title: result["title"].to_s.squish.truncate(500),
        url: result["url"],
        published_at: published_at,
        raw_content: page.text.presence || result["content"].to_s,
        raw_metadata: { "via" => "tavily", "score" => result["score"] }.compact
      }
    end

    def parse_time(value)
      value.present? ? Time.zone.parse(value.to_s) : nil
    rescue ArgumentError
      nil
    end
  end
end
