module Api
  # Journal de bord d'un projet.
  class ProjectEntriesController < ApplicationController
    before_action :set_project
    before_action :set_entry, only: [:update, :destroy]

    # GET /api/projects/:project_id/project_entries
    def index
      render json: @project.project_entries.includes(:contact).chronological.map(&:api_attributes)
    end

    # POST /api/projects/:project_id/project_entries
    def create
      entry = @project.project_entries.new(entry_params)
      if entry.save
        render json: entry.api_attributes, status: :created
      else
        render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/projects/:project_id/project_entries/:id
    def update
      if @entry.update(entry_params)
        render json: @entry.api_attributes
      else
        render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/projects/:project_id/project_entries/:id
    def destroy
      @entry.destroy
      head :no_content
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    def set_entry
      @entry = @project.project_entries.find(params[:id])
    end

    def entry_params
      params.require(:project_entry).permit(:occurred_on, :kind, :title, :body, :contact_id)
    end
  end
end
