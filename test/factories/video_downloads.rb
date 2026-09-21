# == Schema Information
#
# Table name: video_downloads
#
#  id              :bigint           not null, primary key
#  canonical_url   :string
#  completed_at    :datetime
#  description     :text
#  duration        :integer
#  error_message   :text
#  file_size       :bigint
#  filename        :string
#  format          :string           not null
#  platform        :string
#  published_at    :datetime
#  quality         :string
#  status          :string           default("pending"), not null
#  storage         :string           not null
#  thumbnail_url   :string
#  title           :string
#  uploader        :string
#  uploader_handle :string
#  uploader_url    :string
#  url             :string           not null
#  view_count      :bigint
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  video_folder_id :bigint
#
# Indexes
#
#  index_video_downloads_on_created_at       (created_at)
#  index_video_downloads_on_status           (status)
#  index_video_downloads_on_video_folder_id  (video_folder_id)
#
# Foreign Keys
#
#  fk_rails_...  (video_folder_id => video_folders.id)
#
FactoryBot.define do
  factory :video_folder do
    sequence(:name) { |n| "Conferences #{n}" }
  end

  factory :video_download do
    url { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
    format { "mp4" }
    quality { "original" }
    storage { "local" }
    status { "pending" }

    trait :audio do
      format { "mp3" }
      quality { nil }
    end

    trait :cloud do
      storage { "cloud" }
    end

    trait :completed do
      status { "completed" }
      title { "Une video" }
      filename { "Une video [dQw4w9WgXcQ].mp4" }
      file_size { 1_024 }
      duration { 212 }
      completed_at { Time.current }
    end

    trait :failed do
      status { "failed" }
      error_message { "VideoDownloads::YtDlpService::Error: yt-dlp a echoue" }
    end
  end
end
