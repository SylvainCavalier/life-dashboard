module Api
  class CvExperiencesController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      render json: CvExperience.ordered
    end

    def create
      experience = CvExperience.new(experience_params)
      if experience.save
        render json: experience, status: :created
      else
        render json: { errors: experience.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      experience = CvExperience.find(params[:id])
      if experience.update(experience_params)
        render json: experience
      else
        render json: { errors: experience.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      CvExperience.find(params[:id]).destroy
      head :no_content
    end

    private

    def experience_params
      params.require(:cv_experience).permit(
        :title, :company, :location, :start_year, :end_year, :description, :position
      )
    end
  end
end
