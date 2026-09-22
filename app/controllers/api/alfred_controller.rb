module Api
  # Alfred : disponibilite, etat du corpus et reglages.
  class AlfredController < ApplicationController
    # GET /api/alfred
    def show
      render json: overview_json
    end

    # PATCH /api/alfred
    def update
      AlfredSetting.instance.update!(custom_instructions: params[:custom_instructions].to_s.strip.presence)
      render json: overview_json
    end

    # POST /api/alfred/reindex
    # Reindexation complete du corpus (asynchrone). Les empreintes evitent de
    # repayer ce qui n'a pas change.
    def reindex
      return render json: { error: "MISTRAL_API_KEY manquante" }, status: :service_unavailable unless ::Alfred.corpus_configured?

      AlfredReindexJob.perform_later
      render json: { enqueued: true }, status: :accepted
    end

    private

    def overview_json
      {
        available: ::Alfred.configured?,
        missing_keys: ::Alfred.missing_keys,
        model: ::Alfred.model,
        custom_instructions: AlfredSetting.instance.custom_instructions,
        corpus: {
          chunks: AlfredChunk.count,
          records: AlfredIndexEntry.where(status: "indexed").count,
          failed: AlfredIndexEntry.failed.count,
          last_indexed_at: AlfredIndexEntry.maximum(:indexed_at)
        }
      }
    end
  end
end
