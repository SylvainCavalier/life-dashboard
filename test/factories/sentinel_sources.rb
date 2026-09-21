# == Schema Information
#
# Table name: sentinel_sources
#
#  id                   :bigint           not null, primary key
#  active               :boolean          default(TRUE), not null
#  adapter              :string
#  domain               :string           not null
#  feed_url             :string
#  language             :string           default("fr"), not null
#  last_collected_at    :datetime
#  last_documents_count :integer
#  last_error           :text
#  name                 :string           not null
#  on_topic             :boolean          default(FALSE), not null
#  slug                 :string           not null
#  url                  :string
#  web_search           :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_sentinel_sources_on_domain_and_slug  (domain,slug) UNIQUE
#
FactoryBot.define do
  factory :sentinel_source do
    domain { "desinformation" }
    sequence(:name) { |n| "Source #{n}" }
    sequence(:slug) { |n| "source_#{n}" }
    url { "https://www.example.org" }
    feed_url { "https://www.example.org/feed" }
    web_search { false }
    on_topic { true }
    language { "fr" }
    active { true }

    trait :generalist do
      on_topic { false }
    end

    trait :web_only do
      feed_url { nil }
      web_search { true }
    end

    trait :judilibre do
      domain { "droit_travail" }
      name { "Cour de cassation (Judilibre)" }
      slug { "judilibre" }
      adapter { "judilibre" }
      feed_url { nil }
    end

    trait :legifrance do
      domain { "droit_travail" }
      name { "Légifrance" }
      slug { "legifrance" }
      adapter { "legifrance" }
      feed_url { nil }
      on_topic { false }
    end
  end
end
