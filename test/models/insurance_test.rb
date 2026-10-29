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
require "test_helper"

class InsuranceTest < ActiveSupport::TestCase
  test "la cotisation annuelle suit la frequence" do
    assert_equal 222, build(:insurance, premium: 18.5, premium_frequency: "monthly").annual_premium
    assert_equal 400, build(:insurance, premium: 100, premium_frequency: "quarterly").annual_premium
    assert_nil build(:insurance, premium: nil).annual_premium
  end

  test "la prochaine echeance est la date anniversaire, aujourd'hui comprise" do
    insurance = build(:insurance, renewal_date: Date.new(2023, 3, 1))

    assert_equal Date.new(2027, 3, 1), insurance.next_renewal_on(Date.new(2026, 10, 29))
    assert_equal Date.new(2026, 3, 1), insurance.next_renewal_on(Date.new(2026, 3, 1))
    assert_equal Date.new(2023, 3, 1), insurance.next_renewal_on(Date.new(2022, 6, 1))
  end

  test "pas d'echeance sans date, apres la fin ou une fois resilie" do
    assert_nil build(:insurance, renewal_date: nil).next_renewal_on
    assert_nil build(:insurance, renewal_date: Date.new(2023, 3, 1), end_date: Date.new(2026, 12, 31))
                 .next_renewal_on(Date.new(2026, 10, 29))
    assert_nil build(:insurance, renewal_date: Date.new(2023, 3, 1), status: "resiliee").next_renewal_on
  end

  test "type, statut et dates sont valides" do
    assert_not build(:insurance, insurance_type: "spatiale").valid?
    assert_not build(:insurance, status: "perdue").valid?
    assert_not build(:insurance, start_date: Date.new(2026, 5, 1), end_date: Date.new(2026, 1, 1)).valid?
  end

  test "supprimer le contrat garde ses documents et libere le bien" do
    insurance = create(:insurance)
    property = Property.create!(name: "Appartement", property_type: "appartement")
    create(:insured_item, insurance: insurance, property: property)
    document = Document.new(name: "Conditions generales", domain: "insurance", category: "general_terms", insurance: insurance)
    document.file.attach(io: StringIO.new("%PDF-1.4"), filename: "cg.pdf", content_type: "application/pdf")
    document.save!

    insurance.destroy

    assert_nil document.reload.insurance_id
    assert_equal 0, property.insured_items.count
  end
end
