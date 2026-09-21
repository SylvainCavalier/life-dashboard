# Veille sur la désinformation et le complotisme, héritée de FakeNewsletter
# pour la liste de sites et la taxonomie. La collecte combine les flux RSS des
# sites qui en exposent un (le canal principal) et une recherche Tavily
# restreinte aux domaines de la liste, en complément.
module Sentinel
  module Domains
    class Disinformation < Base
      SEARCH_QUERIES = {
        "fr" => "désinformation complotisme fake news",
        "en" => "disinformation conspiracy theories fact-check",
        "es" => "desinformación bulos teorías de la conspiración"
      }.freeze

      # Appliqué aux seules sources généralistes (on_topic: false). Les sources
      # spécialisées sont dans le champ par construction.
      TOPIC_PATTERNS = [
        /d[ée]sinformation|disinformation|misinformation|desinformaci[óo]n/i,
        /fake news|infox|\bintox\b|fausses? (nouvelles?|informations?)/i,
        # « conspiracy » seul est exclu : en anglais c'est aussi l'association de malfaiteurs (conspiracy to murder).
        /complot|conspirationn|conspiracy theor|conspiracist|conspiracism|conspiranoi/i,
        /\bqanon\b/i,
        /fact[- ]?check|v[ée]rification des faits|debunk|d[ée]bunk/i,
        /propagand/i,
        /ing[ée]rences? (num[ée]riques?|[ée]trang[èe]res?)|foreign interference/i,
        /manipulation de l['’]information|op[ée]rations? d['’]influence|influence operation/i,
        /deepfake|hypertrucage/i,
        /\bhoax\b|canular|\bbulos?\b/i,
        /d[ée]rives? sectaires?/i,
        /antivax|anti-vaccin|climatoscepti|climate denial|n[ée]gationnis/i,
        /fermes? [àa] trolls|troll farm/i
      ].freeze

      def key = "desinformation"
      def label = "Désinformation"
      def icon = "🕵️"
      def description = "Complotisme, propagande, ingérences et fact-checking de la semaine"

      def kinds
        { "article" => "Article" }
      end

      def categories
        {
          "etudes-chiffres" => "Études et chiffres",
          "propagande" => "Propagande et ingérences",
          "complosphere" => "Nos complotistes ont du talent",
          "outils" => "Outils",
          "medias" => "Médias",
          "reformes-institutions" => "Réformes et institutions",
          "podcasts" => "Podcasts et vidéos",
          "fact-checking" => "Fact-checking",
          "derives-sectaires" => "Dérives sectaires",
          "intelligence-artificielle" => "Intelligence artificielle",
          "reseaux-sociaux" => "Réseaux sociaux",
          "sante-science" => "Santé et science",
          "autres" => "Autres"
        }
      end

      def search_queries = SEARCH_QUERIES

      # Flux vérifiés le 21/09/2026. Les sites sans flux exploitable (AFP Factuel,
      # NewsGuard, VIGINUM...) ne passent que par la recherche web.
      def default_sources # rubocop:disable Metrics/MethodLength
        [
          { slug: "conspiracy_watch", name: "Conspiracy Watch", url: "https://www.conspiracywatch.info",
            feed_url: "https://www.conspiracywatch.info/feed", on_topic: true },
          { slug: "afp_factuel", name: "AFP Factuel", url: "https://factuel.afp.com", on_topic: true },
          { slug: "les_surligneurs", name: "Les Surligneurs", url: "https://lessurligneurs.eu",
            feed_url: "https://lessurligneurs.eu/feed/", on_topic: true },
          { slug: "les_decodeurs", name: "Le Monde - Les Décodeurs", url: "https://www.lemonde.fr/les-decodeurs/",
            feed_url: "https://www.lemonde.fr/les-decodeurs/rss_full.xml" },
          { slug: "checknews", name: "Libération - CheckNews", url: "https://www.liberation.fr/checknews/",
            feed_url: "https://www.liberation.fr/arc/outboundfeeds/rss-all/category/checknews/?outputType=xml",
            on_topic: true },
          { slug: "fake_off", name: "20 Minutes - Fake Off", url: "https://www.20minutes.fr/societe/desintox/",
            feed_url: "https://www.20minutes.fr/feeds/rss-fake-off.xml", on_topic: true },
          { slug: "vrai_ou_fake", name: "franceinfo - Vrai ou Fake", url: "https://www.francetvinfo.fr/vrai-ou-fake/",
            feed_url: "https://www.francetvinfo.fr/vrai-ou-fake.rss", on_topic: true },
          { slug: "observateurs_france24", name: "Les Observateurs - France 24",
            url: "https://observers.france24.com/fr/" },
          { slug: "rfi", name: "RFI", url: "https://www.rfi.fr" },
          { slug: "viginum", name: "VIGINUM (SGDSN)", url: "https://www.sgdsn.gouv.fr" },
          { slug: "the_conversation", name: "The Conversation", url: "https://theconversation.com",
            feed_url: "https://theconversation.com/fr/topics/desinformation-52725/articles.atom", on_topic: true },
          { slug: "le_parisien", name: "Le Parisien", url: "https://www.leparisien.fr" },
          { slug: "marianne", name: "Marianne", url: "https://www.marianne.net" },
          { slug: "canard_enchaine", name: "Le Canard enchaîné", url: "https://www.lecanardenchaine.fr" },
          { slug: "bellingcat", name: "Bellingcat", url: "https://www.bellingcat.com",
            feed_url: "https://www.bellingcat.com/feed/", language: "en" },
          { slug: "eu_disinfolab", name: "EU DisinfoLab", url: "https://www.disinfo.eu",
            feed_url: "https://www.disinfo.eu/feed/", on_topic: true, language: "en" },
          { slug: "newsguard", name: "NewsGuard", url: "https://www.newsguardtech.com", on_topic: true,
            language: "en" },
          { slug: "snopes", name: "Snopes", url: "https://www.snopes.com",
            feed_url: "https://www.snopes.com/feed/", on_topic: true, language: "en" },
          { slug: "the_guardian", name: "The Guardian", url: "https://www.theguardian.com", language: "en" },
          { slug: "the_insider", name: "The Insider", url: "https://theins.ru",
            feed_url: "https://theins.ru/en/feed", language: "en" },
          { slug: "maldita", name: "Maldita.es", url: "https://maldita.es",
            feed_url: "https://maldita.es/malditobulo/feed/", on_topic: true, language: "es" }
        ].map { |source| { web_search: true }.merge(source) }
      end

      def classify(document)
        return relevant("source:#{document.sentinel_source.slug}") if document.sentinel_source.on_topic?

        haystack = "#{document.title} #{document.raw_content.to_s[0, 6000]}"
        pattern = TOPIC_PATTERNS.find { |candidate| haystack.match?(candidate) }
        return relevant("pattern:#{pattern.source[0, 40]}") if pattern

        irrelevant
      end

      def summary_persona
        <<~TEXT.strip
          Tu es un journaliste spécialisé dans la lutte contre la désinformation et l'étude du complotisme. Tu reçois un article (enquête, fact-check, étude, rapport institutionnel), parfois en anglais ou en espagnol.
          Tu écris en français pour un spécialiste du sujet qui fait sa veille hebdomadaire : ton direct et vivant, sans jargon académique ni formules lisses. Mets en avant ce que l'article révèle ou change : acteurs, narratifs, méthodes, chiffres. N'invente rien et ne reprends jamais une fausse information à ton compte : présente-la toujours comme telle.
        TEXT
      end

      def importance_scale
        <<~TEXT.strip
          - "low" : fact-check ponctuel ou sujet déjà largement connu, sans élément nouveau.
          - "medium" : information notable pour qui suit le sujet (nouveau narratif, acteur qui monte, étude sérieuse, outil utile).
          - "high" : révélation ou enquête majeure, opération d'ingérence documentée, décision politique ou judiciaire structurante, étude de référence.
        TEXT
      end

      def digest_persona
        <<~TEXT.strip
          Tu es un journaliste spécialisé dans la lutte contre la désinformation et l'étude du complotisme. Tu reçois les résumés individuels de tous les articles d'une semaine de veille.
          Tu écris pour un spécialiste du sujet : fais émerger les narratifs et les acteurs de la semaine, ce qui est nouveau, ce qui monte. Ton direct, pas de remplissage.
        TEXT
      end
    end
  end
end
