class CreateFileTransfers < ActiveRecord::Migration[8.0]
  def change
    create_table :file_transfers do |t|
      t.string :token, null: false
      t.string :label
      t.datetime :expires_at, null: false
      t.integer :download_count, null: false, default: 0
      t.datetime :last_downloaded_at

      t.timestamps
    end

    add_index :file_transfers, :token, unique: true
    add_index :file_transfers, :expires_at
  end
end
