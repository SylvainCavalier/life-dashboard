class AddClipToVideoDownloads < ActiveRecord::Migration[8.0]
  def change
    add_column :video_downloads, :clip_start, :integer
    add_column :video_downloads, :clip_end, :integer
  end
end
