module Api
  # Contacts lies a un projet (mini-CRM de la page du projet). Le suivi lui-meme
  # passe par /api/crm_profiles, comme sur la page CRM.
  class ProjectContactsController < ApplicationController
    before_action :set_project
    before_action :set_project_contact, only: [:update, :destroy]

    # GET /api/projects/:project_id/project_contacts
    def index
      links = @project.project_contacts.includes(contact: :crm_profile)
                      .sort_by { |link| [link.contact.last_name.to_s.downcase, link.contact.first_name.to_s.downcase] }
      render json: links.map(&:api_attributes)
    end

    # POST /api/projects/:project_id/project_contacts
    # Lier un contact l'ajoute au CRM s'il n'y etait pas encore.
    def create
      link = @project.project_contacts.new(project_contact_params)
      saved = ProjectContact.transaction do
        link.save && (link.contact.crm_profile || link.contact.create_crm_profile!)
      end
      if saved
        render json: link.reload.api_attributes, status: :created
      else
        render json: { errors: link.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /api/projects/:project_id/project_contacts/:id
    def update
      if @project_contact.update(params.require(:project_contact).permit(:role))
        render json: @project_contact.api_attributes
      else
        render json: { errors: @project_contact.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/projects/:project_id/project_contacts/:id : retire le lien, pas la fiche CRM.
    def destroy
      @project_contact.destroy
      head :no_content
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    def set_project_contact
      @project_contact = @project.project_contacts.find(params[:id])
    end

    def project_contact_params
      params.require(:project_contact).permit(:contact_id, :role)
    end
  end
end
