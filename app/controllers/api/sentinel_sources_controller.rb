module Api
  # Module Sentinelle : sources surveillées. Lecture et création passent par
  # le domaine (/api/sentinel_domains/:key/sources), la modification par l'id.
  class SentinelSourcesController < ApplicationController
    before_action :set_domain, only: [:index, :create, :restore_defaults]
    before_action :set_source, only: [:update, :destroy]

    rescue_from Sentinel::Domains::UnknownDomain do |error|
      render json: { errors: [error.message] }, status: :not_found
    end

    # GET /api/sentinel_domains/:key/sources
    def index
      render json: sources_json
    end

    # POST /api/sentinel_domains/:key/sources
    def create
      source = SentinelSource.new(source_params.merge(domain: @domain.key))
      if source.save
        render json: source.api_attributes, status: :created
      else
        render json: { errors: source.errors.full_messages }, status: :unprocessable_content
      end
    end

    # POST /api/sentinel_domains/:key/sources/restore_defaults
    # Réinstalle les sources par défaut manquantes, sans toucher aux existantes.
    def restore_defaults
      SentinelSource.seed_defaults!(@domain.key)
      render json: sources_json
    end

    # PATCH /api/sentinel_sources/:id
    def update
      if @source.update(source_params)
        render json: @source.api_attributes
      else
        render json: { errors: @source.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /api/sentinel_sources/:id
    # Supprime aussi les documents collectés depuis cette source.
    def destroy
      @source.destroy
      head :no_content
    end

    private

    def set_domain
      @domain = Sentinel::Domains.find!(params[:sentinel_domain_key])
    end

    def set_source
      @source = SentinelSource.find(params[:id])
    end

    def sources_json
      SentinelSource.for_domain(@domain.key).ordered.map(&:api_attributes)
    end

    # `adapter` et `slug` ne sont pas modifiables : un adaptateur est du code,
    # pas un réglage. Une source créée ici est un flux RSS et/ou un site à chercher.
    def source_params
      params.require(:sentinel_source).permit(:name, :url, :feed_url, :web_search, :on_topic, :language, :active)
    end
  end
end
