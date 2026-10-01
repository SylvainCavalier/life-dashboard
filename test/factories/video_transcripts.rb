FactoryBot.define do
  factory :video_transcript do
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
