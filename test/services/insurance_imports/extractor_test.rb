require "test_helper"
require "minitest/mock"

class InsuranceImports::ExtractorTest < ActiveSupport::TestCase
  # Extraction de texte factice : [texte, extracteur], comme Alfred::Corpus::TextExtractor.
  class FakeTextExtractor
    def initialize(text) = @text = text
    def call(_blob) = [@text, "pdf_reader"]
  end

  FIELDS = {
    "name" => "Multirisque habitation - Appartement de Créteil", "insurance_type" => "habitation",
    "insurer" => "MAIF", "policy_number" => "1234567 A", "start_date" => "2024-03-01", "end_date" => "",
    "renewal_date" => "01/03/2024", "premium" => "254,80 €", "premium_frequency" => "yearly",
    "conditions" => "Déclarer tout sinistre sous 5 jours ouvrés.", "claims_phone" => "05 49 00 00 00",
    "advisor_name" => "", "advisor_phone" => "", "advisor_email" => "pas une adresse", "website_url" => "maif.fr",
    "document_category" => "special_terms", "document_name" => "Conditions particulières 2024",
    "coverages" => [
      { "name" => "Dégâts des eaux", "included" => true, "ceiling" => "Valeur à neuf", "deductible" => "150 €",
        "conditions" => "Fuites accidentelles ; défaut d'entretien exclu." },
      { "name" => "Vol", "included" => false, "ceiling" => "", "deductible" => "", "conditions" => "" },
      { "name" => " ", "included" => true, "ceiling" => "", "deductible" => "", "conditions" => "" }
    ],
    "items" => [
      { "name" => "Appartement", "kind" => "logement", "description" => "12 rue X, 94000 Créteil, 3 pièces", "value" => "" },
      { "name" => "MacBook", "kind" => "inconnu", "description" => "", "value" => "2 500" }
    ]
  }.freeze

  test "range et verifie les champs extraits" do
    property = Property.create!(name: "Appart Créteil", property_type: "appartement", postal_code: "94000")
    Property.create!(name: "Maison Drôme", property_type: "maison", postal_code: "26000")

    draft = InsuranceImports::Extractor.normalize(FIELDS)
    insurance = draft[:insurance]

    assert_equal Date.new(2024, 3, 1), insurance[:start_date]
    assert_equal Date.new(2024, 3, 1), insurance[:renewal_date]
    assert_nil insurance[:end_date]
    assert_equal BigDecimal("254.80"), insurance[:premium]
    assert_equal "", insurance[:advisor_email]
    assert_equal "https://maif.fr", insurance[:website_url]
    assert Insurance.new(insurance).valid?

    assert_equal ["Dégâts des eaux", "Vol"], draft[:coverages].pluck(:name)
    assert_not draft[:coverages].last[:included]
    assert_equal property.id, draft[:items].first[:property_id]
    assert_equal "autre", draft[:items].last[:kind]
    assert_equal BigDecimal(2500), draft[:items].last[:value]
    assert_equal({ name: "Conditions particulières 2024", category: "special_terms" }, draft[:document])
  end

  test "valeurs hors liste ramenees a une valeur sure" do
    draft = InsuranceImports::Extractor.normalize({ "insurance_type" => "spatiale", "insurer" => "AXA",
                                                    "premium_frequency" => "weekly", "document_category" => "x" })

    assert_equal "autre", draft[:insurance][:insurance_type]
    assert_equal "Autre - AXA", draft[:insurance][:name]
    assert_equal "yearly", draft[:insurance][:premium_frequency]
    assert_equal "other", draft[:document][:category]
    assert_empty draft[:coverages]
  end

  test "montants" do
    assert_equal BigDecimal("1234.56"), InsuranceImports::Extractor.parse_amount("1.234,56 €")
    assert_equal BigDecimal("1234.56"), InsuranceImports::Extractor.parse_amount("1 234.56")
    assert_nil InsuranceImports::Extractor.parse_amount("néant")
  end

  test "echoue proprement sans texte lisible" do
    extractor = InsuranceImports::Extractor.new(api_key: "test", text_extractor: FakeTextExtractor.new("  "))

    assert_raises(InsuranceImports::Error) { extractor.call(nil) }
  end

  test "enchaine lecture et extraction" do
    extractor = InsuranceImports::Extractor.new(api_key: "test", text_extractor: FakeTextExtractor.new("Contrat MAIF " * 10))
    result = extractor.stub(:extract, FIELDS) { extractor.call(nil) }

    assert_equal "pdf_reader", result[:extractor]
    assert_equal "MAIF", result[:draft][:insurance][:insurer]
  end

  test "sans cle Mistral" do
    assert_raises(InsuranceImports::NotConfigured) { InsuranceImports::Extractor.new(api_key: nil).call(nil) }
  end
end
