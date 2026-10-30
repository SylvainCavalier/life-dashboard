class CreateScriptFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :script_folders do |t|
      t.string :name, null: false
      t.string :platform, null: false, default: "youtube"
      t.string :handle
      t.string :url
      t.text :description
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :script_folders, "lower(name)", unique: true, name: "index_script_folders_on_lower_name"
  end
end
