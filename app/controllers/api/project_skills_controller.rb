module Api
  class ProjectSkillsController < ApplicationController
    before_action :set_project
    before_action :set_skill, only: [:update, :destroy]

    # POST /api/projects/:project_id/project_skills
    def create
      skill = @project.project_skills.new(skill_params)
      if skill.save
        render json: skill.api_attributes, status: :created
      else
        render json: { errors: skill.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/projects/:project_id/project_skills/:id
    def update
      if @skill.update(skill_params)
        render json: @skill.api_attributes
      else
        render json: { errors: @skill.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/projects/:project_id/project_skills/:id
    def destroy
      @skill.destroy
      head :no_content
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    # Scope sur le projet : une competence d'un autre projet repond 404.
    def set_skill
      @skill = @project.project_skills.find(params[:id])
    end

    def skill_params
      params.require(:project_skill).permit(:name, :status, :position)
    end
  end
end
