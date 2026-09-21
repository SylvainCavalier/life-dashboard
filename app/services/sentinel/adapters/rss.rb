require "nokogiri"

# Flux RSS 2.0, RSS 1.0 (RDF) et Atom, lus avec Nokogiri : pas de gem de
# parsing, et une tolérance aux flux mal formés que les parseurs stricts n'ont pas.
# Un flux ne porte souvent qu'un extrait : le texte complet est récupéré plus
# tard par le collecteur, pour les seuls articles retenus.
module Sentinel
  module Adapters
    class Rss
      MAX_RESULTS = 40

      def initialize(source, http: Sentinel::Http)
        @source = source
        @http = http
      end

      def each_document(monday:, **)
        window = SentinelWeek.window(monday)

        entries(@http.get(@source.feed_url)).each do |entry|
          # Sans date, impossible de rattacher l'article à une semaine.
          next unless entry[:published_at] && window.cover?(entry[:published_at])

          yield entry
        end
      end

      private

      def entries(xml)
        document = Nokogiri::XML(xml) { |config| config.recover.nonet }
        document.remove_namespaces!

        document.xpath("//item | //entry").first(MAX_RESULTS).filter_map do |node|
          url = link_of(node)
          title = text_of(node, "title")
          next if url.blank? || title.blank?

          {
            external_id: Sentinel::UrlNormalizer.call(url),
            kind: "article",
            title: title.truncate(500),
            url: url,
            author: text_of(node, "creator") || text_of(node, "author/name") || text_of(node, "author"),
            published_at: date_of(node),
            raw_content: plain(text_of(node, "encoded") || text_of(node, "content") ||
                               text_of(node, "description") || text_of(node, "summary")),
            raw_metadata: { "via" => "rss" }
          }
        end
      end

      # RSS : <link>url</link>. Atom : <link rel="alternate" href="url"/>.
      def link_of(node)
        links = node.xpath("link")
        atom = links.find { |link| link["href"].present? && link["rel"].in?([nil, "alternate"]) }
        (atom ? atom["href"] : links.first&.text).to_s.strip.presence
      end

      def text_of(node, path)
        node.at_xpath(path)&.text&.squish.presence
      end

      def date_of(node)
        value = %w[pubDate published date updated].filter_map { |name| text_of(node, name) }.first
        value ? Time.zone.parse(value) : nil
      rescue ArgumentError
        nil
      end

      def plain(html)
        html.present? ? Nokogiri::HTML.fragment(html).text.squish : ""
      end
    end
  end
end
