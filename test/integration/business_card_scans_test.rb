require "test_helper"
require "minitest/mock"

class BusinessCardScansTest < ActionDispatch::IntegrationTest
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  # Scanner factice : la suite ne parle jamais a Mistral.
  class FakeScanner
    attr_reader :calls

    def initialize(result = nil, &block)
      @result = result
      @block = block
      @calls = []
    end

    def scan(path)
      @calls << path
      @block ? @block.call : @result
    end
  end

  setup { sign_in_owner }

  test "renvoie les champs du contact sans rien enregistrer" do
    fake = FakeScanner.new({ contact: { first_name: "Claire", last_name: "Martin" }, text: "Claire MARTIN" })
    assert_no_difference "Contact.count" do
      BusinessCards.stub(:default, fake) do
        post api_business_card_scans_path, params: { image: image_upload("image/jpeg") }, headers: ACCEPT_JSON
      end
    end

    assert_response :success
    assert_equal "Claire", JSON.parse(response.body).dig("contact", "first_name")
    assert_equal 1, fake.calls.size
  end

  test "refuse un fichier qui n'est pas une image" do
    fake = FakeScanner.new("jamais")
    BusinessCards.stub(:default, fake) do
      post api_business_card_scans_path, params: { image: image_upload("application/pdf") }, headers: ACCEPT_JSON
    end

    assert_response :unprocessable_entity
    assert_empty fake.calls
  end

  test "503 quand la cle Mistral manque" do
    fake = FakeScanner.new { raise BusinessCards::NotConfigured, "MISTRAL_API_KEY manquante" }
    BusinessCards.stub(:default, fake) do
      post api_business_card_scans_path, params: { image: image_upload("image/jpeg") }, headers: ACCEPT_JSON
    end

    assert_response :service_unavailable
  end

  test "502 quand Mistral echoue" do
    fake = FakeScanner.new { raise BusinessCards::Error, "Aucun texte lisible sur la photo" }
    BusinessCards.stub(:default, fake) do
      post api_business_card_scans_path, params: { image: image_upload("image/jpeg") }, headers: ACCEPT_JSON
    end

    assert_response :bad_gateway
    assert_match "Aucun texte lisible", JSON.parse(response.body)["error"]
  end

  test "exige d'etre connecte" do
    sign_out :user
    post api_business_card_scans_path, params: { image: image_upload("image/jpeg") }, headers: ACCEPT_JSON

    assert_response :unauthorized
  end

  private

  def image_upload(content_type)
    Rack::Test::UploadedFile.new(StringIO.new("\xFF\xD8\xFF" + "0" * 2000), content_type, original_filename: "carte.jpg")
  end
end
