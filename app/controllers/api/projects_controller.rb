module Api
  class ProjectsController < ApplicationController
    before_action :set_project, only: [:show, :update, :destroy]

    # GET /api/projects
    def index
      projects = Project.ordered.includes(:project_skills, :project_links, :tasks, :documents)
      render json: projects.map(&:api_attributes)
    end

    # GET /api/projects/:id
    def show
      render json: @project.api_attributes(full: true)
    end

    # GET /api/projects/categories
    def categories
      render json: Project::CATEGORIES.map { |key| { value: key, label: Project::CATEGORY_LABELS[key] } }
    end

    def create
      @project = Project.new(project_params)
      if @project.save
        render json: @project.api_attributes(full: true), status: :created
      else
        render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @project.update(project_params)
        render json: @project.api_attributes(full: true)
      else
        render json: { errors: @project.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @project.destroy
      head :no_content
    end

    private

    def set_project
      @project = Project.includes(:project_skills, :project_links, :tasks, :documents).find(params[:id])
    end

    def project_params
      params.require(:project).permit(
        :name, :description, :category, :status, :priority, :progress,
        :github_url, :site_url, :notes
      )
    end
  end
end
