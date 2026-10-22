require "test_helper"
require "minitest/mock"

class BusinessCards::ScannerTest < ActiveSupport::TestCase
  # OCR factice ; l'extraction (appel de chat) est remplacee par un stub.
  class FakeOcr
    def initialize(text) = @text = text
    def read_image(_file) = @text
  end

  FIELDS = {
    "first_name" => "Claire", "last_name" => "Martin", "job_title" => "Directrice juridique",
    "company" => "ACME", "email" => "Claire.Martin@ACME.fr", "phone" => "06 98 76 54 32",
    "other_phones" => "Fixe : 04 78 00 00 00", "address" => "8 avenue Foch, 69006", "city" => "Lyon",
    "website" => "acme.fr", "linkedin" => "", "other" => ""
  }.freeze

  test "range les champs extraits dans un contact" do
    attrs = BusinessCards::Scanner.contact_attributes(FIELDS, today: Date.new(2026, 10, 22))

    assert_equal "Directrice juridique, ACME", attrs[:occupation]
    assert_equal "claire.martin@acme.fr", attrs[:email]
    assert_equal "connaissance", attrs[:relationship_type]
    assert_equal 2026, attrs[:met_year]
    assert_equal "Site : acme.fr\nFixe : 04 78 00 00 00\nCarte de visite scannée le 22/10/2026", attrs[:notes]
    assert Contact.new(attrs).valid?
  end

  test "un email illisible part dans les notes, pas dans le champ" do
    attrs = BusinessCards::Scanner.contact_attributes(FIELDS.merge("email" => "claire.martin acme.fr"))

    assert_equal "", attrs[:email]
    assert_includes attrs[:notes], "Email lu : claire.martin acme.fr"
  end

  test "echoue proprement sans texte lisible" do
    scanner = BusinessCards::Scanner.new(api_key: "test", ocr: FakeOcr.new("  "))

    assert_raises(BusinessCards::Error) { scanner.scan("carte.jpg") }
  end

  test "enchaine OCR et extraction" do
    scanner = BusinessCards::Scanner.new(api_key: "test", ocr: FakeOcr.new("Claire MARTIN, ACME"))
    result = scanner.stub(:extract, FIELDS) { scanner.scan("carte.jpg") }

    assert_equal "Claire", result[:contact][:first_name]
    assert_equal "Claire MARTIN, ACME", result[:text]
  end

  test "sans cle Mistral" do
    assert_raises(BusinessCards::NotConfigured) { BusinessCards::Scanner.new(api_key: nil, ocr: FakeOcr.new("x")).scan("carte.jpg") }
  end
end
