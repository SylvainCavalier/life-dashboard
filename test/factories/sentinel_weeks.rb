# == Schema Information
#
# Table name: sentinel_weeks
#
#  id                  :bigint           not null, primary key
#  digest              :jsonb            not null
#  digest_generated_at :datetime
#  digest_model        :string
#  domain              :string           not null
#  error               :text
#  finished_at         :datetime
#  monday              :date             not null
#  progress_done       :integer          default(0), not null
#  progress_total      :integer          default(0), not null
#  requested_at        :datetime
#  started_at          :datetime
#  status              :string           default("pending"), not null
#  step                :string
#  warnings            :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_sentinel_weeks_on_domain_and_monday  (domain,monday) UNIQUE
#
FactoryBot.define do
  factory :sentinel_week do
    domain { "desinformation" }
    monday { Date.new(2026, 9, 14) }
    status { "done" }
    requested_at { 1.hour.ago }
    started_at { 1.hour.ago }
    finished_at { 50.minutes.ago }
    digest do
      {
        "tldr" => "Semaine dominée par une campagne d'ingérence documentée par VIGINUM.",
        "key_themes" => ["Ingérences étrangères", "Deepfakes électoraux"],
        "top_documents" => [],
        "impact_summary" => "Un narratif à surveiller dans les semaines qui viennent.",
        "documents_count" => 2
      }
    end
    digest_model { "gpt-test" }
    digest_generated_at { 50.minutes.ago }

    trait :pending do
      status { "pending" }
      requested_at { Time.current }
      started_at { nil }
      finished_at { nil }
      digest { {} }
      digest_model { nil }
      digest_generated_at { nil }
    end

    trait :running do
      pending
      status { "running" }
      step { "summarize" }
      started_at { Time.current }
    end

    trait :failed do
      pending
      status { "failed" }
      error { "OpenAI (HTTP 429) : quota épuisé" }
    end

    trait :labor_law do
      domain { "droit_travail" }
    end
  end
end
