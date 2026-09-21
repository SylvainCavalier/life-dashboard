class CreateVideoDownloads < ActiveRecord::Migration[8.0]
  def change
    create_table :video_downloads do |t|
      t.references :video_folder, null: true, foreign_key: true
      t.string :url, null: false
      t.string :format, null: false
      t.string :quality
      t.string :storage, null: false
      t.string :status, null: false, default: "pending"
      t.string :title
      t.string :filename
      t.bigint :file_size
      t.string :thumbnail_url
      t.text :description
      t.integer :duration
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    add_index :video_downloads, :status
    add_index :video_downloads, :created_at
  end
end
