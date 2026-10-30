module Api
  # Onglet Comparateur de la page Outils. Les deux PDF arrivent en direct upload
  # (signed_id), la comparaison tourne dans DocumentComparisonJob et la page sonde
  # `show`. Ouvert aux amis : chacun ne voit que ses comparaisons. Voir DocumentComparison.
  class DocumentComparisonsController < ApplicationController
    open_to_friends

    HISTORY_SIZE = 20

    before_action :set_comparison, only: [:show, :destroy]

    def index
      render json: {
        enabled: DocumentComparisons.enabled?,
        max_bytes: DocumentComparison::MAX_BYTES,
        comparisons: current_user.document_comparisons.recent.limit(HISTORY_SIZE).map(&:api_attributes)
      }
    end

    def show
      render json: @comparison.api_attributes
    end

    def create
      unless DocumentComparisons.enabled?
        return render json: { errors: ["Comparateur indisponible : MISTRAL_API_KEY manquante"] }, status: :service_unavailable
      end

      comparison = current_user.document_comparisons.new(focus: params[:focus].to_s.strip.presence)
      comparison.file_a.attach(params[:file_a]) if params[:file_a].present?
      comparison.file_b.attach(params[:file_b]) if params[:file_b].present?
      if comparison.save
        comparison.start!
        render json: comparison.api_attributes, status: :created
      else
        render json: { errors: comparison.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @comparison.purge_files!
      @comparison.destroy
      head :no_content
    end

    private

    def set_comparison
      @comparison = current_user.document_comparisons.find(params[:id])
    end
  end
end
