class CreatePasswordEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :password_entries do |t|
      t.string :name, null: false
      t.string :login, null: false
      t.string :password, null: false

      t.timestamps
    end
  end
end
