require "test_helper"

class LettersTest < ActionDispatch::IntegrationTest
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  def tiptap(text)
    { type: "doc", content: [{ type: "paragraph", attrs: { textAlign: "justify" }, content: [{ type: "text", text: text, marks: [{ type: "bold" }] }] }] }
  end

  test "enregistre un brouillon avec le JSON de l'editeur puis le modifie" do
    post api_letters_path, params: { letter: { subject: "Préavis", body: tiptap("Je donne congé.") } }, as: :json
    assert_response :created
    letter = Letter.find(JSON.parse(response.body)["id"])
    assert_equal "Je donne congé.", letter.body_text
    assert_equal "justify", letter.body["content"][0]["attrs"]["textAlign"]

    patch api_letter_path(letter), params: { letter: { recipient: "Agence Durand", window_envelope: true } }, as: :json
    assert_response :success
    assert_equal "Agence Durand", letter.reload.recipient
    assert letter.window_envelope
    assert_equal "Je donne congé.", letter.body_text, "le contenu n'est pas efface quand il n'est pas envoye"

    get api_letters_path, headers: ACCEPT_JSON
    assert_equal ["Préavis"], JSON.parse(response.body).map { |l| l["label"] }
  end

  test "exporte l'etat du formulaire en PDF et en DOCX sans rien enregistrer" do
    assert_no_difference -> { Letter.count } do
      post export_api_letters_path, params: { file_format: "pdf", letter: { subject: "Objet test", body: tiptap("Bonjour") } }, as: :json
      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert response.body.start_with?("%PDF")
      assert_match(/courrier-\d{4}-\d{2}-\d{2}-objet-test\.pdf/, response.headers["Content-Disposition"])

      post export_api_letters_path, params: { file_format: "docx", letter: { subject: "Objet test" } }, as: :json
      assert_response :success
      assert response.body.start_with?("PK")
    end
  end

  test "refuse un format inconnu" do
    post export_api_letters_path, params: { file_format: "odt", letter: { subject: "x" } }, as: :json
    assert_response :unprocessable_entity
  end

  test "range le PDF dans les documents puis le remplace" do
    letter = create(:letter)

    post save_to_documents_api_letter_path(letter), as: :json
    assert_response :success
    document = JSON.parse(response.body)["document"]
    assert_equal "Courrier - Résiliation de mon abonnement", document["name"]

    assert_no_difference -> { Document.count } do
      post save_to_documents_api_letter_path(letter), as: :json
    end
  end

  test "pre-remplit l'expediteur depuis le profil" do
    PersonalProfile.create!(first_name: "Sylvain", last_name: "Cavalier", address_line1: "12 rue des Lilas",
                            postal_code: "94000", city: "Créteil", country: "France", email: "s@example.fr")

    get defaults_api_letters_path, headers: ACCEPT_JSON

    body = JSON.parse(response.body)
    assert_equal "Sylvain Cavalier\n12 rue des Lilas\n94000 Créteil\ns@example.fr", body["sender"]
    assert_equal "Créteil", body["place"]
    assert_equal "Sylvain Cavalier", body["signatory"]
    assert_nil body["signature_data_url"]
  end

  test "supprime un brouillon" do
    letter = create(:letter)
    delete api_letter_path(letter), headers: ACCEPT_JSON
    assert_response :no_content
    assert_not Letter.exists?(letter.id)
  end
end
