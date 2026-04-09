module Api
  class PasswordEntriesController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @entries = PasswordEntry.order(created_at: :desc)
      render json: @entries
    end

    def create
      @entry = PasswordEntry.new(entry_params)
      if @entry.save
        render json: @entry, status: :created
      else
        render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @entry = PasswordEntry.find(params[:id])
      @entry.destroy
      head :no_content
    end

    private

    def entry_params
      params.require(:password_entry).permit(:name, :login, :password)
    end
  end
end
