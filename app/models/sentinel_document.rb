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
# Document collecté par Sentinelle (décision, texte officiel, article...) avec
# son tri déterministe (`relevant`) et son résumé IA. Un document hors champ
# est conservé, sans son texte, pour que le tri reste auditable.
class SentinelDocument < ApplicationRecord
  IMPORTANCES = %w[low medium high].freeze
  IMPORTANCE_RANK = { "high" => 0, "medium" => 1, "low" => 2 }.freeze

  belongs_to :sentinel_source

  validates :domain, inclusion: { in: ->(_) { Sentinel::Domains.keys } }
  validates :monday, :external_id, :kind, :title, presence: true
  validates :external_id, uniqueness: { scope: :sentinel_source_id }
  validates :importance, inclusion: { in: IMPORTANCES }, allow_nil: true

  scope :relevant, -> { where(relevant: true) }
  scope :summarized, -> { where.not(summarized_at: nil) }
  scope :unsummarized, -> { where(summarized_at: nil) }

  def summarized?
    summarized_at.present?
  end

  # Tri d'affichage : importance décroissante, puis du plus récent au plus ancien.
  def sort_key
    [IMPORTANCE_RANK.fetch(importance, 3), -(published_at || created_at).to_i]
  end

  def api_attributes(full: false)
    json = {
      id: id, source_id: sentinel_source_id, source_name: sentinel_source.name, kind: kind,
      title: title, display_title: display_title, url: url, author: author, published_at: published_at,
      relevant: relevant, relevance_reason: relevance_reason, tldr: tldr, importance: importance,
      categories: categories, summarized: summarized?
    }
    return json unless full

    json.merge(key_points: key_points, summary_model: summary_model, summarized_at: summarized_at,
               raw_content: raw_content, monday: monday, domain: domain)
  end
end
