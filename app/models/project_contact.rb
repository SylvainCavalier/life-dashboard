# == Schema Information
#
# Table name: project_contacts
#
#  id         :bigint           not null, primary key
#  role       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  contact_id :bigint           not null
#  project_id :bigint           not null
#
# Indexes
#
#  index_project_contacts_on_contact_id                 (contact_id)
#  index_project_contacts_on_project_id                 (project_id)
#  index_project_contacts_on_project_id_and_contact_id  (project_id,contact_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (project_id => projects.id)
#

# Contact important pour un projet (role : « conseiller du pole de competitivite »...).
# Le suivi (priorite, dernier contact, prochain rendez-vous) reste sur le CrmProfile du
# contact, unique et partage avec la page CRM : la page du projet n'en est qu'un filtre.
class ProjectContact < ApplicationRecord
  belongs_to :project
  belongs_to :contact

  validates :contact_id, uniqueness: { scope: :project_id, message: "est deja lie a ce projet" }
  validates :role, length: { maximum: 120 }

  def api_attributes
    {
      id: id, project_id: project_id, contact_id: contact_id, role: role,
      contact: contact.as_json(only: %i[id first_name last_name phone email occupation]),
      crm_profile: contact.crm_profile&.as_json(except: %i[created_at updated_at])
    }
  end
end
