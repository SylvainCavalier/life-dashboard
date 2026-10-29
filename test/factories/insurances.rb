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
FactoryBot.define do
  factory :insurance do
    name { "Multirisque habitation" }
    insurance_type { "habitation" }
    insurer { "MAIF" }
    status { "active" }
    premium { 18.5 }
    premium_frequency { "monthly" }
  end

  factory :insurance_coverage do
    insurance
    name { "Dégâts des eaux" }
    included { true }
    ceiling { "valeur à neuf" }
    deductible { "150 €" }
    conditions { "Fuites accidentelles uniquement" }
  end

  factory :insured_item do
    insurance
    name { "Appartement de Créteil" }
    kind { "logement" }
  end
end
