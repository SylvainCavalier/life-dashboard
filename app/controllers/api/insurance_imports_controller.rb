module Api
  # Creation d'une assurance a partir de son contrat. Le fichier arrive en direct upload
  # (signed_id), l'extraction tourne dans InsuranceImportJob et la page sonde `show` ;
  # `confirm` cree le contrat relu par Sylvain, avec ses garanties, ses biens et le
  # Document du fichier. Voir InsuranceImport.
  class InsuranceImportsController < ApplicationController
    before_action :set_import, only: [:show, :confirm, :destroy]

    def create
      unless InsuranceImports.enabled?
        return render json: { errors: ["Import indisponible : MISTRAL_API_KEY manquante"] }, status: :service_unavailable
      end

      InsuranceImport.purge_stale!
      import = InsuranceImport.new
      import.file.attach(params[:file]) if params[:file].present?
      if import.save
        import.start!
        render json: import.api_attributes, status: :created
      else
        render json: { errors: import.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def show
      render json: @import.api_attributes
    end

    # POST /api/insurance_imports/:id/confirm
    def confirm
      insurance = @import.confirm!(
        insurance: params.require(:insurance).permit(*InsurancesController::PERMITTED),
        coverages: confirm_params.fetch(:coverages, []),
        items: confirm_params.fetch(:items, []),
        document: confirm_params.fetch(:document, {})
      )
      render json: insurance.api_attributes(full: true), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end

    def destroy
      @import.destroy
      head :no_content
    end

    private

    def set_import
      @import = InsuranceImport.find(params[:id])
    end

    def confirm_params
      @confirm_params ||= params.permit(
        coverages: [:name, :included, :ceiling, :deductible, :conditions],
        items: [:name, :kind, :description, :value, :property_id],
        document: [:name, :category]
      )
    end
  end
end
