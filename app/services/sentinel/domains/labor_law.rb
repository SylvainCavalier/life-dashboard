# Veille en droit du travail, reprise du projet veille-juridique :
# jurisprudence de la chambre sociale (Judilibre), textes publiés au JO
# (Légifrance) et doctrine (Village de la Justice).
module Sentinel
  module Domains
    class LaborLaw < Base
      # Préfixes NOR des ministères sociaux : un texte Légifrance qui en porte un
      # relève du champ, quel que soit son titre.
      LABOR_NOR_PREFIXES = %w[TRS MTR MTS TSS TRT MES ASE TEN ETS].freeze

      LABOR_PATTERNS = [
        /\bcode du travail\b/i,
        /\bconvention collective\b/i,
        /\bcontrat de travail\b/i,
        /\bdurée du travail\b/i,
        /\binspection du travail\b/i,
        /\brepr[ée]sentation du personnel\b/i,
        /\bcomit[ée] social (et|économique)\b/i,
        /\bsanté au travail\b/i,
        /\bsécurité au travail\b/i,
        /\bharcèlement (moral|sexuel)\b/i,
        /\bminist(re|ère) du travail\b/i,
        /\bdialogue social\b/i,
        /\bprud'hom/i,
        /\bnégociation collective\b/i,
        /\bformation professionnelle\b/i,
        /\bactivité partielle\b/i,
        /\bassurance chômage\b/i,
        /\bépargne salariale\b/i
      ].freeze

      def key = "droit_travail"
      def label = "Droit du travail"
      def icon = "⚖️"
      def description = "Jurisprudence sociale, textes officiels et doctrine de la semaine"

      def kinds
        { "jurisprudence" => "Jurisprudence", "reform" => "Texte officiel", "doctrine" => "Doctrine" }
      end

      def categories
        {
          "contrat-de-travail" => "Contrat de travail",
          "rupture-licenciement" => "Rupture et licenciement",
          "temps-de-travail" => "Temps de travail",
          "remuneration" => "Rémunération",
          "conges-absences" => "Congés et absences",
          "sante-securite" => "Santé et sécurité",
          "harcelement-discrimination" => "Harcèlement et discrimination",
          "representation-personnel" => "Représentation du personnel",
          "negociation-collective" => "Négociation collective",
          "formation-professionnelle" => "Formation professionnelle",
          "protection-sociale" => "Protection sociale",
          "travail-detache" => "Travail détaché",
          "contentieux-prudhomal" => "Contentieux prud'homal"
        }
      end

      def default_sources
        [
          { slug: "judilibre", name: "Cour de cassation (Judilibre)", adapter: "judilibre", on_topic: true,
            url: "https://www.courdecassation.fr/recherche-judilibre" },
          { slug: "legifrance", name: "Légifrance (Journal officiel)", adapter: "legifrance",
            url: "https://www.legifrance.gouv.fr" },
          { slug: "village_justice", name: "Village de la Justice", adapter: "village_justice", on_topic: true,
            url: "https://www.village-justice.com/articles/droit-social" }
        ]
      end

      def classify(document)
        return relevant("source:#{document.sentinel_source.slug}") if document.sentinel_source.on_topic?

        prefix = document.raw_metadata["nor"].to_s[0, 3]
        return relevant("nor_prefix:#{prefix}") if LABOR_NOR_PREFIXES.include?(prefix)

        haystack = "#{document.title} #{document.raw_content}"
        pattern = LABOR_PATTERNS.find { |candidate| haystack.match?(candidate) }
        return relevant("pattern:#{pattern.source[0, 40]}") if pattern

        irrelevant
      end

      def summary_persona
        <<~TEXT.strip
          Tu es un juriste spécialisé en droit du travail français. Tu reçois un texte juridique : décision de la Cour de cassation, texte publié au Journal officiel (loi, ordonnance, décret, arrêté) ou article de doctrine.
          Tu écris pour un autre juriste, praticien du contentieux prud'homal, qui fait sa veille hebdomadaire : va à l'essentiel (qui, quoi, portée pratique), cite les articles du Code du travail et les références utiles quand elles figurent dans le texte, n'invente rien.
          Pour une décision de justice, le titre d'origine n'est qu'une référence (date, numéro de pourvoi) : renseigne TOUJOURS "display_title" avec un titre descriptif qui dit la question tranchée et la solution. Pour un texte officiel au titre à rallonge, fais de même.
        TEXT
      end

      def importance_scale
        <<~TEXT.strip
          - "low" : changement mineur ou technique, décision d'espèce sans portée pratique large.
          - "medium" : modification ou précision notable, cantonnée à un domaine ou à un type de situation.
          - "high" : revirement de jurisprudence, décision de principe (publiée au Bulletin ou au Rapport), réforme structurelle.
        TEXT
      end

      def digest_persona
        <<~TEXT.strip
          Tu es un juriste spécialisé en droit du travail français. Tu reçois les résumés individuels de tous les textes (jurisprudence, textes officiels, doctrine) d'une semaine de veille.
          Tu écris pour un autre juriste : fais émerger les tendances et ce qui change réellement la pratique.
        TEXT
      end
    end
  end
end
