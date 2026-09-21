class CreateVideoFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :video_folders do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :video_folders, "lower(name)", unique: true, name: "index_video_folders_on_lower_name"
  end
end
