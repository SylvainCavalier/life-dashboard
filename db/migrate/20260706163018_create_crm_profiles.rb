class CreateCrmProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :crm_profiles do |t|
      t.references :contact, null: false, foreign_key: true, index: { unique: true }
      t.string :priority, null: false, default: "moyenne"
      t.date :last_contact_on
      t.string :last_contact_method
      t.date :next_appointment_on
      t.text :notes

      t.timestamps
    end
  end
end
