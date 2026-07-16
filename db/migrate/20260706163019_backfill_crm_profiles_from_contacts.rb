class BackfillCrmProfilesFromContacts < ActiveRecord::Migration[8.0]
  def up
    Contact.where(callback_pending: true).find_each do |contact|
      CrmProfile.create!(contact_id: contact.id, next_appointment_on: contact.callback_on)
    end
  end

  def down
    # no-op — migration de données
  end
end
