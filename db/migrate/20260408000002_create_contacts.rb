class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.string :last_name, null: false
      t.string :first_name, null: false
      t.date :birth_date
      t.string :gender
      t.string :occupation
      t.string :city
      t.string :phone
      t.string :email
      t.date :last_contacted_on
      t.string :relationship_type, null: false, default: "connaissance"

      t.timestamps
    end

    add_index :contacts, :relationship_type
    add_index :contacts, [:last_name, :first_name]
  end
end
