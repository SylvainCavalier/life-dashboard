# == Schema Information
#
# Table name: meetings
#
#  id               :bigint           not null, primary key
#  context          :text
#  duration_seconds :integer
#  error            :text
#  finished_at      :datetime
#  held_at          :datetime         not null
#  kind             :string           default("in_person"), not null
#  participants     :text
#  requested_at     :datetime
#  speaker_names    :jsonb            not null
#  status           :string           default("pending"), not null
#  step             :string
#  summary          :jsonb            not null
#  summary_model    :string
#  title            :string           not null
#  transcript       :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  document_id      :bigint
#
# Indexes
#
#  index_meetings_on_document_id  (document_id)
#  index_meetings_on_held_at      (held_at)
#
# Foreign Keys
#
#  fk_rails_...  (document_id => documents.id) ON DELETE => nullify
#
FactoryBot.define do
  factory :meeting do
    title { "Point sur le bail" }
    kind { "in_person" }
    held_at { Time.zone.parse("2026-09-22 10:00") }
    participants { "Sylvain, Marie" }

    trait :with_audio do
      after(:build) do |meeting|
        meeting.audio.attach(io: StringIO.new("fake audio"), filename: "reunion.m4a", content_type: "audio/mp4")
      end
    end

    trait :transcribed do
      duration_seconds { 15 }
      transcript do
        [
          { "speaker" => "speaker_1", "start" => 0.1, "end" => 3.9, "text" => "Bonjour Marie, on fait le point sur le bail." },
          { "speaker" => "speaker_1", "start" => 4.1, "end" => 6.2, "text" => "Le locataire part en decembre." },
          { "speaker" => "speaker_2", "start" => 6.2, "end" => 11.2, "text" => "J'envoie l'etat des lieux avant le 15 novembre." }
        ]
      end
    end
  end
end
