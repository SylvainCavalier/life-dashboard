module Api
  # Page Scripts : dossiers de classement, un par chaine YouTube ou compte de reseau social.
  class ScriptFoldersController < ApplicationController
    PERMITTED = %i[name platform handle url description position].freeze

    before_action :set_folder, only: [:update, :destroy]

    # GET /api/script_folders
    def index
      counts = Script.group(:script_folder_id).count
      render json: {
        folders: ScriptFolder.ordered.map { |folder| folder.api_attributes(scripts_count: counts.fetch(folder.id, 0)) },
        unfiled_count: counts.fetch(nil, 0)
      }
    end

    def create
      folder = ScriptFolder.new(folder_params)
      if folder.save
        render json: folder.api_attributes(scripts_count: 0), status: :created
      else
        render json: { errors: folder.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @folder.update(folder_params)
        render json: @folder.api_attributes(scripts_count: @folder.scripts.count)
      else
        render json: { errors: @folder.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Les scripts du dossier sont conserves, sans dossier.
    def destroy
      @folder.destroy
      head :no_content
    end

    private

    def set_folder
      @folder = ScriptFolder.find(params[:id])
    end

    def folder_params
      params.require(:script_folder).permit(*PERMITTED)
    end
  end
end
