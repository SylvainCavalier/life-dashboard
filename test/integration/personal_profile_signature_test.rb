require "test_helper"

class PersonalProfileSignatureTest < ActionDispatch::IntegrationTest
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze
  # PNG 1x1 transparent
  PNG_BYTES = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")

  setup do
    sign_in_owner
    @profile = PersonalProfile.create!(first_name: "Sylvain", last_name: "Cavalier")
  end

  test "ajoute une signature PNG et la renvoie en data URL" do
    patch api_personal_profile_path, params: { personal_profile: { signature: png_upload } }, headers: ACCEPT_JSON

    assert_response :success
    assert @profile.reload.signature.attached?
    assert_match %r{\Adata:image/png;base64,}, JSON.parse(response.body)["signature_data_url"]

    get api_personal_profile_path, headers: ACCEPT_JSON
    assert_match %r{\Adata:image/png;base64,}, JSON.parse(response.body)["signature_data_url"]
  end

  test "refuse un fichier qui n'est pas un PNG" do
    jpeg = Rack::Test::UploadedFile.new(StringIO.new("pas une image"), "image/jpeg", original_filename: "signature.jpg")
    patch api_personal_profile_path, params: { personal_profile: { signature: jpeg } }, headers: ACCEPT_JSON

    assert_response :unprocessable_entity
    assert_not @profile.reload.signature.attached?
  end

  test "supprime la signature" do
    @profile.signature.attach(io: StringIO.new(PNG_BYTES), filename: "signature.png", content_type: "image/png")

    delete signature_api_personal_profile_path, headers: ACCEPT_JSON

    assert_response :success
    assert_nil JSON.parse(response.body)["signature_data_url"]
    assert_not @profile.reload.signature.attached?
  end

  test "la modification du profil ne touche pas a la signature" do
    @profile.signature.attach(io: StringIO.new(PNG_BYTES), filename: "signature.png", content_type: "image/png")

    patch api_personal_profile_path, params: { personal_profile: { city: "Creteil" } }, headers: ACCEPT_JSON, as: :json

    assert_response :success
    assert @profile.reload.signature.attached?
  end

  private

  def png_upload
    Rack::Test::UploadedFile.new(StringIO.new(PNG_BYTES), "image/png", original_filename: "signature.png")
  end
end
