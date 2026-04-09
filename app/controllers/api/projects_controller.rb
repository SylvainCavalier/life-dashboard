module Api
  class ProjectsController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @projects = Project.ordered
      render json: @projects
    end

    def create
      @project = Project.new(project_params)
      if @project.save
        render json: @project, status: :created
      else
        render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @project = Project.find(params[:id])
      if @project.update(project_params)
        render json: @project
      else
        render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @project = Project.find(params[:id])
      @project.destroy
      head :no_content
    end

    private

    def project_params
      params.require(:project).permit(
        :name, :description, :status, :priority, :progress,
        :github_url, :site_url, :notes
      )
    end
  end
end
