# == Schema Information
#
# Table name: insurances
#
#  id                :bigint           not null, primary key
#  advisor_email     :string
#  advisor_name      :string
#  advisor_phone     :string
#  claims_phone      :string
#  conditions        :text
#  end_date          :date
#  insurance_type    :string           not null
#  insurer           :string
#  name              :string           not null
#  notes             :text
#  policy_number     :string
#  premium           :decimal(10, 2)
#  premium_frequency :string           default("yearly"), not null
#  renewal_date      :date
#  start_date        :date
#  status            :string           default("active"), not null
#  website_url       :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_insurances_on_insurance_type  (insurance_type)
#

# Contrat d'assurance (page Assurances). Ses garanties (InsuranceCoverage) disent
# contre quoi il couvre et a quelles conditions, ses biens assures (InsuredItem) ce
# qu'il couvre, et ses documents (Document, domaine `insurance`) portent le texte
# qui fait foi : conditions generales et particulieres, indexees dans le corpus d'Alfred.
class Insurance < ApplicationRecord
  TYPES = %w[
    habitation auto moto sante prevoyance vie emprunteur responsabilite_civile
    protection_juridique professionnelle voyage animaux scolaire autre
  ].freeze

  TYPE_LABELS = {
    "habitation" => "Habitation", "auto" => "Auto", "moto" => "Moto / deux-roues", "sante" => "Santé / mutuelle",
    "prevoyance" => "Prévoyance", "vie" => "Assurance vie", "emprunteur" => "Emprunteur",
    "responsabilite_civile" => "Responsabilité civile", "protection_juridique" => "Protection juridique",
    "professionnelle" => "Professionnelle (RC pro...)", "voyage" => "Voyage", "animaux" => "Animaux",
    "scolaire" => "Scolaire", "autre" => "Autre"
  }.freeze

  STATUSES = %w[active suspendue resiliee].freeze
  PREMIUM_FREQUENCIES = %w[monthly quarterly semiannual yearly].freeze
  PAYMENTS_PER_YEAR = { "monthly" => 12, "quarterly" => 4, "semiannual" => 2, "yearly" => 1 }.freeze

  has_many :insurance_coverages, -> { order(:position, :id) }, dependent: :destroy
  has_many :insured_items, -> { order(:id) }, dependent: :destroy
  # Les documents restent dans la page Documents si le contrat est supprime.
  has_many :documents, dependent: :nullify

  validates :name, presence: true
  validates :insurance_type, presence: true, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :premium_frequency, inclusion: { in: PREMIUM_FREQUENCIES }
  validates :premium, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :website_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validate :end_date_after_start_date

  scope :ordered, -> { order(Arel.sql("CASE status WHEN 'active' THEN 0 WHEN 'suspendue' THEN 1 ELSE 2 END"), :name) }

  def annual_premium
    premium && (premium * PAYMENTS_PER_YEAR.fetch(premium_frequency, 1))
  end

  # Prochaine echeance principale (aujourd'hui comprise) : date anniversaire de
  # renewal_date. C'est avant elle qu'on resilie. nil sans date, contrat resilie ou fini avant.
  def next_renewal_on(today = Date.current)
    return nil if renewal_date.nil? || status == "resiliee"

    years = [today.year - renewal_date.year, 0].max
    date = renewal_date >> (12 * years)
    date = renewal_date >> (12 * (years += 1)) while date < today
    date unless end_date && date > end_date
  end

  def api_attributes(full: false)
    json = attributes.symbolize_keys.merge(
      type_label: TYPE_LABELS[insurance_type],
      annual_premium: annual_premium,
      next_renewal_on: next_renewal_on,
      coverages_count: insurance_coverages.size,
      items_count: insured_items.size,
      documents_count: documents.size,
      item_names: insured_items.map(&:name)
    )
    return json unless full

    json.merge(
      coverages: insurance_coverages.map(&:api_attributes),
      items: insured_items.map(&:api_attributes)
    )
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date && end_date < start_date

    errors.add(:end_date, "doit etre posterieure a la date de debut")
  end
end
