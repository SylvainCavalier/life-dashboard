module Api
  # Page Assurances : contrats, avec leurs garanties et biens assures imbriques
  # (/insurances/:id/insurance_coverages, /insured_items). Les documents passent par
  # /documents avec ?insurance_id= (domaine `insurance`).
  class InsurancesController < ApplicationController
    PERMITTED = %i[
      name insurance_type insurer policy_number status start_date end_date renewal_date
      premium premium_frequency conditions notes
      advisor_name advisor_phone advisor_email claims_phone website_url
    ].freeze

    before_action :set_insurance, only: [:show, :update, :destroy]

    # GET /api/insurances
    def index
      insurances = Insurance.ordered.includes(:insurance_coverages, :insured_items, :documents)
      render json: insurances.map(&:api_attributes)
    end

    # GET /api/insurances/:id
    def show
      render json: @insurance.api_attributes(full: true)
    end

    # GET /api/insurances/options : listes des formulaires (types, frequences, natures de bien)
    def options
      render json: {
        types: Insurance::TYPES.map { |key| { value: key, label: Insurance::TYPE_LABELS[key] } },
        statuses: Insurance::STATUSES,
        premium_frequencies: Insurance::PREMIUM_FREQUENCIES,
        item_kinds: InsuredItem::KINDS,
        document_categories: Document::CATEGORIES["insurance"]
      }
    end

    def create
      @insurance = Insurance.new(insurance_params)
      if @insurance.save
        render json: @insurance.api_attributes(full: true), status: :created
      else
        render json: { errors: @insurance.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @insurance.update(insurance_params)
        render json: @insurance.api_attributes(full: true)
      else
        render json: { errors: @insurance.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @insurance.destroy
      head :no_content
    end

    private

    def set_insurance
      @insurance = Insurance.includes(:documents, insured_items: :property).find(params[:id])
    end

    def insurance_params
      params.require(:insurance).permit(*PERMITTED)
    end
  end
end
