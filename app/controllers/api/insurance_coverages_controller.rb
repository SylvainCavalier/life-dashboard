module Api
  # Garanties d'un contrat d'assurance (page de l'assurance).
  class InsuranceCoveragesController < ApplicationController
    before_action :set_insurance
    before_action :set_coverage, only: [:update, :destroy]

    def create
      coverage = @insurance.insurance_coverages.new(coverage_params)
      coverage.position = (@insurance.insurance_coverages.maximum(:position) || -1) + 1 if coverage.position.zero?
      if coverage.save
        render json: coverage.api_attributes, status: :created
      else
        render json: { errors: coverage.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @coverage.update(coverage_params)
        render json: @coverage.api_attributes
      else
        render json: { errors: @coverage.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @coverage.destroy
      head :no_content
    end

    private

    def set_insurance
      @insurance = Insurance.find(params[:insurance_id])
    end

    def set_coverage
      @coverage = @insurance.insurance_coverages.find(params[:id])
    end

    def coverage_params
      params.require(:insurance_coverage).permit(:name, :included, :ceiling, :deductible, :conditions, :position)
    end
  end
end
