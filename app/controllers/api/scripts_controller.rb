module Api
  # Page Scripts : scripts de videos, threads et posts. L'index renvoie un extrait du texte,
  # le show le texte complet ; l'editeur enregistre au fil de la frappe (PATCH).
  class ScriptsController < ApplicationController
    PERMITTED = %i[script_folder_id title kind status body notes planned_on published_on published_url].freeze

    before_action :set_script, only: [:show, :update, :destroy]

    # GET /api/scripts
    def index
      render json: Script.ordered.includes(:script_folder).map { |script| script.api_attributes(full: false) }
    end

    def show
      render json: @script.api_attributes
    end

    def create
      script = Script.new(script_params)
      if script.save
        render json: script.api_attributes, status: :created
      else
        render json: { errors: script.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @script.update(script_params)
        render json: @script.api_attributes
      else
        render json: { errors: @script.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @script.destroy
      head :no_content
    end

    private

    def set_script
      @script = Script.find(params[:id])
    end

    def script_params
      params.require(:script).permit(*PERMITTED)
    end
  end
end
