# == Schema Information
#
# Table name: video_transcripts
#
#  id                :bigint           not null, primary key
#  duration_seconds  :integer
#  error             :text
#  finished_at       :datetime
#  language          :string           default("auto"), not null
#  requested_at      :datetime
#  source_citation   :text
#  speaker_names     :jsonb            not null
#  status            :string           default("pending"), not null
#  step              :string
#  summary           :jsonb            not null
#  summary_model     :string
#  title             :string           not null
#  transcribed_at    :datetime
#  transcript        :jsonb            not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  document_id       :bigint
#  user_id           :bigint           not null
#  video_download_id :bigint
#
# Indexes
#
#  index_video_transcripts_on_created_at         (created_at)
#  index_video_transcripts_on_document_id        (document_id)
#  index_video_transcripts_on_user_id            (user_id)
#  index_video_transcripts_on_video_download_id  (video_download_id)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (video_download_id => video_downloads.id) ON DELETE => nullify
#
FactoryBot.define do
  factory :video_transcript do
    user { User.owner || association(:user) }
    title { "Interview sur la desinformation" }
    language { "auto" }

    trait :with_video do
      after(:build) do |transcript|
        transcript.video.attach(io: StringIO.new("fake video"), filename: "interview.mp4", content_type: "video/mp4")
      end
    end

    trait :transcribed do
      with_video
      duration_seconds { 12 }
      transcribed_at { Time.current }
      transcript do
        [
          { "speaker" => "speaker_1", "start" => 0.1, "end" => 0.9, "text" => "Добрий день!" },
          { "speaker" => "speaker_1", "start" => 1.1, "end" => 7.5, "text" => "Сьогодні ми поговоримо про дезінформацію." },
          { "speaker" => "speaker_2", "start" => 8.0, "end" => 11.5, "text" => "Merci de m'accueillir." }
        ]
      end
    end
  end
end
