# Les outils ouverts aux amis (Downloader, Transfert, outil Videos) gardent leurs donnees
# par compte. Tout l'existant appartient au proprietaire.
class AddUserToSharedTools < ActiveRecord::Migration[8.0]
  TABLES = %i[video_folders video_downloads video_transcripts file_transfers].freeze

  def up
    TABLES.each { |table| add_reference table, :user, foreign_key: true }

    owner_id = select_value("SELECT id FROM users WHERE role = 'owner' ORDER BY id LIMIT 1")
    TABLES.each do |table|
      next unless select_value("SELECT 1 FROM #{table} LIMIT 1")
      raise "Aucun compte proprietaire pour reprendre les lignes de #{table}" unless owner_id

      execute "UPDATE #{table} SET user_id = #{Integer(owner_id)}"
    end
    TABLES.each { |table| change_column_null table, :user_id, false }

    # Deux amis peuvent avoir chacun leur dossier « Conferences ».
    remove_index :video_folders, name: "index_video_folders_on_lower_name"
    add_index :video_folders, "user_id, lower((name)::text)", unique: true, name: "index_video_folders_on_user_and_lower_name"
  end

  def down
    remove_index :video_folders, name: "index_video_folders_on_user_and_lower_name"
    add_index :video_folders, "lower((name)::text)", unique: true, name: "index_video_folders_on_lower_name"
    TABLES.each { |table| remove_reference table, :user, foreign_key: true }
  end
end
