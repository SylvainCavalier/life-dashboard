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
# Source surveillée par Sentinelle, rattachée à un seul domaine de veille.
# Une source se collecte par n'importe quelle combinaison de trois canaux :
# un adaptateur dédié (API officielle ou scraper), un flux RSS/Atom, et la
# recherche web Tavily restreinte à son nom de domaine.
class SentinelSource < ApplicationRecord
  ADAPTERS = %w[judilibre legifrance village_justice].freeze

  has_many :sentinel_documents, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :domain },
                   format: { with: /\A[a-z0-9_]+\z/, message: "ne doit contenir que des minuscules, chiffres et _" }
  validates :domain, inclusion: { in: ->(_) { Sentinel::Domains.keys } }
  validates :adapter, inclusion: { in: ADAPTERS }, allow_nil: true
  validates :url, :feed_url, format: { with: %r{\Ahttps?://}i, message: "doit etre une URL http(s)" },
                             allow_blank: true
  validate :collectable
  validate :web_search_needs_url

  before_validation :normalize

  scope :for_domain, ->(domain) { where(domain: domain.to_s) }
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :searchable, -> { where(web_search: true).where.not(url: [nil, ""]) }

  # Installe (ou complète) les sources par défaut d'un domaine. Idempotent :
  # une source existante n'est jamais écrasée, les réglages manuels survivent.
  def self.seed_defaults!(domain_key)
    domain = Sentinel::Domains.find!(domain_key)
    domain.default_sources.count do |attributes|
      source = find_or_initialize_by(domain: domain.key, slug: attributes[:slug])
      next false if source.persisted?

      source.update!(attributes)
      true
    end
  end

  # Première visite d'un domaine vierge : on installe ses sources. Un domaine
  # déjà utilisé n'est jamais re-rempli (l'utilisateur a pu tout supprimer exprès).
  def self.bootstrap!(domain_key)
    return 0 if for_domain(domain_key).exists? || SentinelWeek.for_domain(domain_key).exists?

    seed_defaults!(domain_key)
  end

  # Nom d'hôte sans www, utilisé pour restreindre Tavily et rattacher ses résultats.
  def host
    return nil if url.blank?

    URI.parse(url).host.to_s.sub(/\Awww\./, "").presence
  rescue URI::InvalidURIError
    nil
  end

  def channels
    [adapter && "api", feed_url.present? && "rss", web_search? && "web"].select(&:itself)
  end

  def record_collection!(count:, error: nil)
    update!(last_collected_at: Time.current, last_documents_count: count, last_error: error&.truncate(500))
  end

  def api_attributes
    {
      id: id, domain: domain, name: name, slug: slug, url: url, adapter: adapter, feed_url: feed_url,
      web_search: web_search, on_topic: on_topic, language: language, active: active, channels: channels,
      last_collected_at: last_collected_at, last_documents_count: last_documents_count, last_error: last_error
    }
  end

  private

  def normalize
    self.slug = name.to_s.parameterize(separator: "_") if slug.blank?
    self.adapter = adapter.presence
    self.feed_url = feed_url.presence&.strip
    self.url = url.presence&.strip
  end

  def collectable
    return if adapter.present? || feed_url.present? || web_search?

    errors.add(:base, "Une source doit avoir un flux RSS, la recherche web ou un adaptateur")
  end

  def web_search_needs_url
    errors.add(:url, "est obligatoire pour la recherche web") if web_search? && host.blank?
  end
end
