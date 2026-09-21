module Api
  # Module Sentinelle : liste des domaines de veille (un onglet par domaine).
  class SentinelDomainsController < ApplicationController
    # GET /api/sentinel_domains
    def index
      latest = SentinelWeek.recent.group_by(&:domain).transform_values(&:first)

      domains = Sentinel::Domains.all.map do |domain|
        # Premier affichage d'un domaine vierge : on installe ses sources par défaut.
        SentinelSource.bootstrap!(domain.key)
        week = latest[domain.key]

        domain.as_json.merge(
          sources_count: SentinelSource.for_domain(domain.key).active.count,
          latest_week: week && { monday: week.monday, status: week.status, has_digest: week.digest? }
        )
      end

      render json: { domains: domains, configuration: configuration }
    end

    private

    # Clés manquantes signalées dans la page, plutôt qu'un échec au premier lancement.
    def configuration
      {
        openai: Sentinel::Llm.configured?,
        piste: Sentinel::Piste::Client.configured?,
        tavily: Sentinel::TavilySearch.configured?
      }
    end
  end
end
