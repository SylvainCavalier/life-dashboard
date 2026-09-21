module Api
  class ProjectLinksController < ApplicationController
    before_action :set_project
    before_action :set_link, only: [:update, :destroy]

    # POST /api/projects/:project_id/project_links
    def create
      link = @project.project_links.new(link_params)
      if link.save
        render json: link.api_attributes, status: :created
      else
        render json: { errors: link.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/projects/:project_id/project_links/:id
    def update
      if @link.update(link_params)
        render json: @link.api_attributes
      else
        render json: { errors: @link.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/projects/:project_id/project_links/:id
    def destroy
      @link.destroy
      head :no_content
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    # Scope sur le projet : un lien d'un autre projet repond 404.
    def set_link
      @link = @project.project_links.find(params[:id])
    end

    def link_params
      params.require(:project_link).permit(:title, :url, :position)
    end
  end
end
