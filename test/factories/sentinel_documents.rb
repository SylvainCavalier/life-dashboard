# == Schema Information
#
# Table name: sentinel_documents
#
#  id                 :bigint           not null, primary key
#  author             :string
#  categories         :jsonb            not null
#  display_title      :string
#  domain             :string           not null
#  importance         :string
#  key_points         :jsonb            not null
#  kind               :string           not null
#  monday             :date             not null
#  published_at       :datetime
#  raw_content        :text
#  raw_metadata       :jsonb            not null
#  relevance_reason   :string
#  relevant           :boolean
#  summarized_at      :datetime
#  summary_model      :string
#  title              :string           not null
#  tldr               :text
#  url                :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  external_id        :string           not null
#  sentinel_source_id :bigint           not null
#
# Indexes
#
#  index_sentinel_documents_on_domain_and_monday                   (domain,monday)
#  index_sentinel_documents_on_sentinel_source_id                  (sentinel_source_id)
#  index_sentinel_documents_on_sentinel_source_id_and_external_id  (sentinel_source_id,external_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (sentinel_source_id => sentinel_sources.id)
#
FactoryBot.define do
  factory :sentinel_document do
    sentinel_source
    domain { sentinel_source.domain }
    monday { Date.new(2026, 9, 14) }
    sequence(:external_id) { |n| "example.org/article-#{n}" }
    kind { "article" }
    sequence(:title) { |n| "Article #{n}" }
    url { "https://www.example.org/article" }
    published_at { Time.zone.local(2026, 9, 16, 10) }
    raw_content { "Une enquête sur une campagne de désinformation coordonnée." }
    relevant { true }
    relevance_reason { "source:test" }

    trait :summarized do
      tldr { "Une campagne coordonnée a été documentée." }
      key_points { ["Point 1", "Point 2", "Point 3"] }
      importance { "medium" }
      categories { ["propagande"] }
      summary_model { "gpt-test" }
      summarized_at { Time.current }
    end

    trait :irrelevant do
      relevant { false }
      relevance_reason { "no_signal" }
      raw_content { nil }
    end
  end
end
