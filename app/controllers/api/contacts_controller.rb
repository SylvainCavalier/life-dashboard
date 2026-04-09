module Api
  class ContactsController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @contacts = Contact.ordered
      render json: @contacts
    end

    def create
      @contact = Contact.new(contact_params)
      if @contact.save
        render json: @contact, status: :created
      else
        render json: { errors: @contact.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @contact = Contact.find(params[:id])
      if @contact.update(contact_params)
        render json: @contact
      else
        render json: { errors: @contact.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @contact = Contact.find(params[:id])
      @contact.destroy
      head :no_content
    end

    private

    def contact_params
      params.require(:contact).permit(
        :first_name, :last_name, :birth_date, :gender, :occupation,
        :city, :phone, :email, :last_contacted_on, :relationship_type, :followed,
        :notes, :likes, :dislikes, :loans,
        :address, :met_through, :met_year,
        :social_instagram, :social_linkedin, :social_twitter,
        :social_facebook, :social_tiktok, :social_snapchat, :social_youtube
      )
    end
  end
end
