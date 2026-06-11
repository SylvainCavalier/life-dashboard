module Api
  class CvSkillsController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      render json: CvSkill.ordered
    end

    def create
      skill = CvSkill.new(skill_params)
      if skill.save
        render json: skill, status: :created
      else
        render json: { errors: skill.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      skill = CvSkill.find(params[:id])
      if skill.update(skill_params)
        render json: skill
      else
        render json: { errors: skill.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      CvSkill.find(params[:id]).destroy
      head :no_content
    end

    private

    def skill_params
      params.require(:cv_skill).permit(:name, :category, :level, :position)
    end
  end
end
