require "nokogiri"

# Doctrine : rubrique « Droit social » de Village de la Justice. Pas d'API ni
# de flux RSS par rubrique (vérifié : le backend SPIP renvoie un flux vide),
# donc scraping de la page de rubrique puis de chaque article.
# (veille-juridique visait l'index par mot-clé « droit du travail », qui n'est
# plus alimenté depuis juillet 2026 : l'URL se règle sur la source.)
#
# Le scraping dépend de classes CSS du site : une refonte le casse. C'est
# pourquoi une page d'index dont on ne tire AUCUN article lève une erreur
# (remontée en avertissement dans l'interface) au lieu de renvoyer 0 document
# en silence, comme le faisait veille-juridique.
module Sentinel
  module Adapters
    class VillageJustice
      class LayoutChanged < StandardError; end

      BASE_URL = "https://www.village-justice.com".freeze
      DEFAULT_INDEX_URL = "#{BASE_URL}/articles/droit-social".freeze
      MAX_RESULTS = 60
      PAGE_SIZE = 20
      MAX_PAGES = 6
      FRENCH_MONTHS = {
        "janvier" => 1, "février" => 2, "fevrier" => 2, "mars" => 3, "avril" => 4, "mai" => 5, "juin" => 6,
        "juillet" => 7, "août" => 8, "aout" => 8, "septembre" => 9, "octobre" => 10, "novembre" => 11,
        "décembre" => 12, "decembre" => 12
      }.freeze

      def initialize(source, http: Sentinel::Http)
        @index_url = source.url.presence || DEFAULT_INDEX_URL
        @http = http
      end

      def each_document(monday:, sunday:)
        entries = paginated_entries(monday)
        dated = entries.select { |entry| entry[:published_at] }
        oldest = dated.map { |entry| entry[:published_at] }.min
        if oldest && sunday < oldest
          raise LayoutChanged, "la rubrique ne remonte qu'au #{oldest.strftime('%d/%m/%Y')} : semaine trop ancienne"
        end

        dated.select { |entry| entry[:published_at].between?(monday, sunday) }.first(MAX_RESULTS).each do |entry|
          yield normalize(entry, article_text(entry[:url]))
        end
      end

      private

      # La rubrique liste 20 articles par page (?debut_artsuiv=20, 40...) : on
      # avance jusqu'à dépasser le lundi visé, dans la limite de MAX_PAGES.
      def paginated_entries(monday)
        entries = []

        MAX_PAGES.times do |page|
          separator = @index_url.include?("?") ? "&" : "?"
          url = page.zero? ? @index_url : "#{@index_url}#{separator}debut_artsuiv=#{page * PAGE_SIZE}"
          batch = parse_index(@http.get(url)).reject { |entry| entries.any? { |e| e[:external_id] == entry[:external_id] } }
          if batch.empty?
            break unless page.zero?

            raise LayoutChanged, "aucun article trouvé sur la page de rubrique : la structure du site a probablement changé"
          end

          entries.concat(batch)
          oldest = batch.filter_map { |entry| entry[:published_at] }.min
          break if oldest.nil? || oldest < monday
        end

        entries
      end

      # Deux gabarits coexistent sur le site (pages de rubrique et pages d'index par
      # mot-clé). Points communs sur lesquels on s'appuie : le titre porte la classe
      # txt-bleu-titre à l'intérieur du lien de l'article, dont l'URL finit par
      # ",<id>.html", et la date de publication est dans un <em> du bloc de l'article.
      def parse_index(html)
        seen = {}
        Nokogiri::HTML(html).css(".txt-bleu-titre").filter_map do |heading|
          link = heading.ancestors("a").first
          next unless link && link["href"].to_s =~ /,(\d+)\.html/

          external_id = Regexp.last_match(1)
          next if seen[external_id]

          seen[external_id] = true
          block, published_at = dated_block(link)
          title, author = split_author(heading.text.squish)
          {
            external_id: external_id,
            title: title,
            url: resolve_url(link["href"]),
            author: author || block&.at_css("i")&.text&.squish&.sub(/\APar\s+/, "").presence,
            excerpt: (link.at_css(".txt-gris") || block&.at_css("p:not(.text-08)"))&.text&.squish,
            published_at: published_at
          }
        end
      end

      # Remonte depuis le lien jusqu'au premier bloc dont un <em> porte une date.
      # On ne lit que les <em> : le chapô cite souvent d'autres dates (« arrêt du 25 juin 2026 »).
      def dated_block(link)
        link.ancestors.first(5).each do |node|
          date = node.css("em").filter_map { |em| parse_french_date(em.text) }.first
          return [node, date] if date
        end
        [nil, nil]
      end

      # Sur les pages de rubrique, l'auteur est collé au titre : « Titre. Par Prénom Nom, Avocat. »
      def split_author(text)
        match = text.match(/\A(.+?)[.!?]?\s+Par\s+(\p{Lu}.+)\z/)
        match ? [match[1].strip, match[2].strip] : [text, nil]
      end

      def article_text(url)
        page = Nokogiri::HTML(@http.get(url))
        node = page.at_css("div.texte-article.texte-reader") || page.at_css(".texte-article") ||
               page.at_css(".texte-reader")
        node&.text&.squish
      rescue Sentinel::Http::Error => e
        Rails.logger.warn "[Sentinelle] Village de la Justice #{url} : #{e.message}"
        nil
      end

      def normalize(entry, text)
        {
          external_id: entry[:external_id],
          kind: "doctrine",
          title: entry[:title],
          url: entry[:url],
          author: entry[:author],
          published_at: entry[:published_at],
          raw_content: text.presence || entry[:excerpt].to_s,
          raw_metadata: {}
        }
      end

      def parse_french_date(text)
        match = text.to_s.strip.downcase.match(/(\d{1,2})(?:er)?\s+([[:alpha:]]+)\s+(\d{4})/)
        month = match && FRENCH_MONTHS[match[2]]
        month ? Date.new(match[3].to_i, month, match[1].to_i) : nil
      rescue Date::Error
        nil
      end

      # Les liens sont relatifs à /articles/ ("slug,id.html"), parfois sous la
      # forme "articles/../slug,id.html" qu'il ne faut pas résoudre littéralement.
      def resolve_url(href)
        return href if href.start_with?("http")

        URI.join("#{BASE_URL}/articles/", href.sub(%r{\A/?articles/(\.\./)?}, "")).to_s
      end
    end
  end
end
