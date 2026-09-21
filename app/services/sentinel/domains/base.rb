# Contrat d'un domaine de veille. Tout ce qui distingue un domaine d'un autre
# passe par ces méthodes : le pipeline (collecte, résumés, synthèse) est
# générique et ne connaît aucun domaine en particulier.
module Sentinel
  module Domains
    class Base
      Classification = Struct.new(:relevant, :reason)

      # Identifiant stable, stocké en base dans les colonnes `domain`.
      def key = raise(NotImplementedError)
      def label = raise(NotImplementedError)
      def icon = raise(NotImplementedError)
      def description = raise(NotImplementedError)

      # { "jurisprudence" => "Jurisprudence", ... } : types de documents du domaine.
      def kinds = raise(NotImplementedError)

      # { "slug" => "Libellé" } : catégories proposées au modèle pour classer un document.
      def categories = raise(NotImplementedError)

      # Sources installées par SentinelSource.seed_defaults! (attributs de SentinelSource).
      def default_sources = raise(NotImplementedError)

      # Requêtes de recherche web par langue de source ({ "fr" => "...", "en" => "..." }).
      # Vide si le domaine n'utilise pas la recherche web. Courtes et sans
      # opérateurs : voir Sentinel::TavilySearch.
      def search_queries = {}

      # Tri déterministe fait AVANT tout appel au modèle : peu coûteux et
      # auditable (la raison est stockée sur le document).
      def classify(_document) = raise(NotImplementedError)

      # Rôle et consignes propres au domaine, injectés dans les prompts génériques.
      def summary_persona = raise(NotImplementedError)
      def importance_scale = raise(NotImplementedError)
      def digest_persona = raise(NotImplementedError)

      def as_json(*)
        {
          key: key,
          label: label,
          icon: icon,
          description: description,
          kinds: kinds,
          categories: categories
        }
      end

      private

      def relevant(reason) = Classification.new(true, reason)
      def irrelevant(reason = "no_signal") = Classification.new(false, reason)
    end
  end
end
