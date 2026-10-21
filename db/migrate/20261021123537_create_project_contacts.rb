class CreateProjectContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :project_contacts do |t|
      t.references :project, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :role
      t.timestamps
    end
    add_index :project_contacts, [:project_id, :contact_id], unique: true
  end
end
