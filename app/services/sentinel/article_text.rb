require "nokogiri"

# Lecture « au mieux » d'une page d'article : son texte et sa date de
# publication. Sert à compléter un flux RSS qui ne donne qu'un extrait, et à
# dater les résultats de la recherche web (Tavily ne date pas ses résultats
# hors grands médias). Volontairement rustique, sans gem de « readability ».
# Un échec ou un paywall n'est pas une erreur : on fait alors avec ce que l'on a.
module Sentinel
  module ArticleText
    Page = Struct.new(:text, :published_at)

    MIN_PARAGRAPH = 60
    MIN_BODY = 400
    MAX_LENGTH = 40_000
    DATE_SELECTORS = [
      ['meta[property="article:published_time"]', "content"],
      ['meta[itemprop="datePublished"]', "content"],
      ['meta[name="date"]', "content"],
      ['meta[name="pubdate"]', "content"],
      ['meta[name="publish-date"]', "content"],
      ['meta[name="DC.date.issued"]', "content"],
      ["time[datetime]", "datetime"]
    ].freeze

    def self.read(url, http: Sentinel::Http)
      html = http.get(url, timeout: 20)
      Page.new(extract(html), published_at(html))
    rescue Sentinel::Http::Error, URI::InvalidURIError => e
      Rails.logger.info "[Sentinelle] page illisible #{url} : #{e.message}"
      Page.new(nil, nil)
    end

    def self.fetch(url, http: Sentinel::Http)
      read(url, http: http).text
    end

    # Trois candidats pour le corps de l'article : le conteneur dont les
    # paragraphes DIRECTS portent le plus de texte, la première balise <article>
    # et <main>. On garde celui qui donne le plus de texte. Aucun ne suffit seul :
    # sur Conspiracy Watch le premier <article> est une vignette de colonne
    # latérale, sur franceinfo les paragraphes sont répartis dans des blocs imbriqués.
    def self.extract(html)
      page = Nokogiri::HTML(html)
      page.css("script, style, nav, header, footer, aside, form, noscript").remove

      densest = page.css("article, main, section, div").max_by { |node| direct_text_length(node) }
      text = [densest, page.at_css("article"), page.at_css("main")].compact.map { |node| paragraphs_of(node) }
                                                                   .max_by(&:length).to_s
      text = paragraphs_of(page.at_css("body")) if text.length < MIN_BODY
      text.truncate(MAX_LENGTH).presence
    end

    def self.paragraphs_of(node)
      return "" unless node

      node.css("p, h2, h3, li, blockquote").map { |element| element.text.squish }
          .select { |line| line.length >= MIN_PARAGRAPH }.uniq.join("\n\n")
    end

    def self.direct_text_length(node)
      node.xpath("./p").sum { |paragraph| paragraph.text.length }
    end

    def self.published_at(html)
      page = Nokogiri::HTML(html)
      candidates = DATE_SELECTORS.filter_map { |selector, attribute| page.at_css(selector)&.[](attribute) }
      candidates << html[/"datePublished"\s*:\s*"([^"]+)"/, 1]

      candidates.compact.each do |value|
        time = Time.zone.parse(value)
        return time if time
      rescue ArgumentError
        next
      end
      nil
    end
  end
end
