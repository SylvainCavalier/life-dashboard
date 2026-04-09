module Api
  class NotesController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @notes = Note.ordered
      render json: @notes
    end

    def create
      @note = Note.new(note_params)
      if @note.save
        render json: @note, status: :created
      else
        render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @note = Note.find(params[:id])
      if @note.update(note_params)
        render json: @note
      else
        render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @note = Note.find(params[:id])
      @note.destroy
      head :no_content
    end

    private

    def note_params
      params.require(:note).permit(:title, :content, :note_date, :important)
    end
  end
end
