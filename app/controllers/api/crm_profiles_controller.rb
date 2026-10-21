module Api
  class CrmProfilesController < ApplicationController
    def index
      @crm_profiles = CrmProfile.includes(contact: :projects).ordered
      render json: @crm_profiles.map { |profile| profile_json(profile) }
    end

    def create
      @crm_profile = CrmProfile.new(crm_profile_params)
      if @crm_profile.save
        render json: profile_json(@crm_profile), status: :created
      else
        render json: { errors: @crm_profile.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @crm_profile = CrmProfile.find(params[:id])
      if @crm_profile.update(crm_profile_params)
        render json: profile_json(@crm_profile)
      else
        render json: { errors: @crm_profile.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      CrmProfile.find(params[:id]).destroy
      head :no_content
    end

    private

    # Projets auxquels le contact est lie (ProjectContact) : badges de la page CRM.
    def profile_json(profile)
      profile.as_json(include: :contact).merge(
        "projects" => profile.contact.projects.map { |project| { id: project.id, name: project.name } }
      )
    end

    def crm_profile_params
      params.require(:crm_profile).permit(
        :contact_id, :priority, :last_contact_on, :last_contact_method,
        :next_appointment_on, :notes
      )
    end
  end
end
