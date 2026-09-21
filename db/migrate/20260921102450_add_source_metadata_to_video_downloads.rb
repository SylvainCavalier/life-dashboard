class AddSourceMetadataToVideoDownloads < ActiveRecord::Migration[8.0]
  def change
    add_column :video_downloads, :platform, :string
    add_column :video_downloads, :canonical_url, :string
    add_column :video_downloads, :uploader, :string
    add_column :video_downloads, :uploader_handle, :string
    add_column :video_downloads, :uploader_url, :string
    add_column :video_downloads, :published_at, :datetime
    add_column :video_downloads, :view_count, :bigint
  end
end
