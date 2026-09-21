module Api
  # Dossiers de classement du module Downloader (telechargements cloud uniquement).
  class VideoFoldersController < ApplicationController
    before_action :set_folder, only: [:show, :update, :destroy]

    # GET /api/video_folders
    def index
      counts = VideoDownload.where.not(video_folder_id: nil).group(:video_folder_id).count
      render json: VideoFolder.ordered.map { |folder| folder_json(folder, counts[folder.id] || 0) }
    end

    # GET /api/video_folders/:id
    def show
      render json: folder_json(@folder)
    end

    # POST /api/video_folders
    def create
      folder = VideoFolder.new(folder_params)
      if folder.save
        render json: folder_json(folder, 0), status: :created
      else
        render json: { errors: folder.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH /api/video_folders/:id
    def update
      if @folder.update(folder_params)
        render json: folder_json(@folder)
      else
        render json: { errors: @folder.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /api/video_folders/:id
    # Les telechargements du dossier sont conserves et redeviennent non classes.
    def destroy
      @folder.destroy
      head :no_content
    end

    private

    def set_folder
      @folder = VideoFolder.find(params[:id])
    end

    def folder_params
      params.require(:video_folder).permit(:name)
    end

    def folder_json(folder, downloads_count = folder.video_downloads.count)
      {
        id: folder.id,
        name: folder.name,
        downloads_count: downloads_count,
        created_at: folder.created_at
      }
    end
  end
end
