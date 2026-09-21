module Api
  class CvFormationsController < ApplicationController
    def index
      render json: CvFormation.ordered
    end

    def create
      formation = CvFormation.new(formation_params)
      if formation.save
        render json: formation, status: :created
      else
        render json: { errors: formation.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      formation = CvFormation.find(params[:id])
      if formation.update(formation_params)
        render json: formation
      else
        render json: { errors: formation.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      CvFormation.find(params[:id]).destroy
      head :no_content
    end

    private

    def formation_params
      params.require(:cv_formation).permit(
        :title, :institution, :category, :location, :start_year, :end_year, :description, :position
      )
    end
  end
end
