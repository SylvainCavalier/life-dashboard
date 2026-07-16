module Api
  class CrmProfilesController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @crm_profiles = CrmProfile.includes(:contact).ordered
      render json: @crm_profiles.as_json(include: :contact)
    end

    def create
      @crm_profile = CrmProfile.new(crm_profile_params)
      if @crm_profile.save
        render json: @crm_profile.as_json(include: :contact), status: :created
      else
        render json: { errors: @crm_profile.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @crm_profile = CrmProfile.find(params[:id])
      if @crm_profile.update(crm_profile_params)
        render json: @crm_profile.as_json(include: :contact)
      else
        render json: { errors: @crm_profile.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      CrmProfile.find(params[:id]).destroy
      head :no_content
    end

    private

    def crm_profile_params
      params.require(:crm_profile).permit(
        :contact_id, :priority, :last_contact_on, :last_contact_method,
        :next_appointment_on, :notes
      )
    end
  end
end
