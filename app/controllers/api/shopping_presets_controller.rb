module Api
  # Cartes d'articles habituels de la page Courses.
  class ShoppingPresetsController < ApplicationController
    before_action :set_preset, only: [:update, :destroy]

    # GET /api/shopping_presets
    def index
      render json: ShoppingPreset.ordered
    end

    def create
      preset = ShoppingPreset.new(preset_params)
      if preset.save
        render json: preset, status: :created
      else
        render json: { errors: preset.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @preset.update(preset_params)
        render json: @preset
      else
        render json: { errors: @preset.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @preset.destroy
      head :no_content
    end

    private

    def set_preset
      @preset = ShoppingPreset.find(params[:id])
    end

    def preset_params
      params.require(:shopping_preset).permit(:name, :icon)
    end
  end
end
