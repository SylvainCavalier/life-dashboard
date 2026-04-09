class Document < ApplicationRecord
  has_one_attached :file

  DOMAINS = %w[health real_estate taxes companies general].freeze

  CATEGORIES = {
    "health" => %w[analysis prescription report certificate imaging vaccination other],
    "real_estate" => %w[lease deed diagnostic insurance invoice tax_notice other],
    "taxes" => %w[income_tax property_tax notice declaration receipt other],
    "companies" => %w[invoice quote contract kbis statutes other],
    "general" => %w[identity administrative insurance other]
  }.freeze

  validates :name, presence: true
  validates :domain, presence: true, inclusion: { in: DOMAINS }
  validates :category, inclusion: { in: ->(doc) { CATEGORIES.fetch(doc.domain, []) } }, allow_blank: true
  validates :file, presence: true

  scope :for_domain, ->(domain) { where(domain: domain) }
end
