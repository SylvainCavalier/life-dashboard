module Api
  class PasswordEntriesController < ApplicationController
    # L'index ne renvoie JAMAIS les mots de passe : une session compromise ou
    # une faille XSS ne doit pas suffire a exfiltrer le coffre-fort entier en
    # une requete. La revelation se fait entree par entree, via #reveal.
    def index
      render json: PasswordEntry.order(created_at: :desc).as_json(only: [:id, :name, :login, :created_at, :updated_at])
    end

    # GET /api/password_entries/:id/reveal
    def reveal
      entry = PasswordEntry.find(params[:id])
      Rails.logger.info("[vault] reveal entry=#{entry.id} name=#{entry.name.inspect} ip=#{request.remote_ip}")
      render json: { id: entry.id, password: entry.password }
    end

    def create
      @entry = PasswordEntry.new(entry_params)
      if @entry.save
        render json: @entry.as_json(only: [:id, :name, :login, :created_at, :updated_at]), status: :created
      else
        render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      PasswordEntry.find(params[:id]).destroy
      head :no_content
    end

    private

    def entry_params
      params.require(:password_entry).permit(:name, :login, :password)
    end
  end
end
