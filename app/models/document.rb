# == Schema Information
#
# Table name: documents
#
#  id            :bigint           not null, primary key
#  category      :string
#  document_date :date
#  domain        :string           not null
#  name          :string           not null
#  notes         :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  company_id    :bigint
#
# Indexes
#
#  index_documents_on_company_id           (company_id)
#  index_documents_on_domain               (domain)
#  index_documents_on_domain_and_category  (domain,category)
#
# Foreign Keys
#
#  fk_rails_...  (company_id => companies.id)
#
class Document < ApplicationRecord
  belongs_to :company, optional: true
  has_one_attached :file

  DOMAINS = %w[
    health real_estate taxes companies general
    education invoices banking civil_status work leisure
  ].freeze

  CATEGORIES = {
    "health" => %w[analysis prescription report certificate imaging vaccination other],
    "real_estate" => %w[lease deed diagnostic insurance invoice tax_notice other],
    "taxes" => %w[income_tax property_tax notice declaration receipt other],
    "companies" => %w[invoice quote contract kbis statutes other],
    "general" => %w[identity administrative insurance other],
    "education" => %w[diploma certificate transcript course_material other],
    "invoices" => %w[utility telecom subscription service purchase other],
    "banking" => %w[statement contract card_info loan other],
    "civil_status" => %w[id_card passport birth_certificate family_book marriage_certificate other],
    "work" => %w[contract payslip certificate evaluation other],
    "leisure" => %w[ticket booking membership manual other]
  }.freeze

  validates :name, presence: true
  validates :domain, presence: true, inclusion: { in: DOMAINS }
  validates :category, inclusion: { in: ->(doc) { CATEGORIES.fetch(doc.domain, []) } }, allow_blank: true
  validates :file, presence: true

  scope :for_domain, ->(domain) { where(domain: domain) }
end
