module Api
  # Memoire d'Alfred, relue et corrigee a la main depuis la page Alfred. Alfred,
  # lui, passe par propose_memory et une confirmation dans le chat.
  class AlfredMemoriesController < ApplicationController
    before_action :set_memory, only: [:update, :destroy]

    # GET /api/alfred_memories
    def index
      render json: list_json
    end

    # POST /api/alfred_memories
    def create
      AlfredMemory.create!(memory_params)
      render json: list_json, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    # PATCH /api/alfred_memories/:id
    def update
      @memory.update!(memory_params)
      render json: list_json
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    # DELETE /api/alfred_memories/:id
    def destroy
      @memory.destroy!
      render json: list_json
    end

    private

    def set_memory
      @memory = AlfredMemory.find(params[:id])
    end

    def memory_params
      params.require(:alfred_memory).permit(:content, :category, :subject_type, :subject_id)
    end

    def list_json
      {
        memories: AlfredMemory.ordered.map do |memory|
          memory.slice(:id, :content, :category, :subject_type, :subject_id, :created_at, :updated_at)
                .merge(category_label: memory.category_label)
        end,
        categories: AlfredMemory::CATEGORIES.map { |key, label| { key: key, label: label } },
        max: AlfredMemory::MAX_MEMORIES,
        max_length: AlfredMemory::MAX_LENGTH
      }
    end
  end
end
