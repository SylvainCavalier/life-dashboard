require "test_helper"

class TransfersTest < ActionDispatch::IntegrationTest
  # Les pages /t/:token sont publiques, mais l'API de creation d'un transfert
  # est derriere l'authentification comme le reste du dashboard.
  def create_transfer(expires_at: 2.days.from_now, label: nil)
    transfer = FileTransfer.new(expires_at: expires_at, label: label)
    transfer.file.attach(
      io: StringIO.new("contenu de test"),
      filename: "photo.jpg",
      content_type: "image/jpeg"
    )
    transfer.tap(&:save!)
  end

  test "la page publique affiche le fichier partage" do
    transfer = create_transfer(label: "Pour Alexia")

    get transfer_path(transfer.token)

    assert_response :success
    assert_match "photo.jpg", response.body
    assert_match "Pour Alexia", response.body
  end

  test "un lien expire renvoie la page d'expiration" do
    transfer = create_transfer(expires_at: 1.minute.ago)

    get transfer_path(transfer.token)

    assert_response :gone
    assert_match "n'est plus valide", response.body
  end

  test "un token inconnu renvoie la page d'expiration" do
    get transfer_path("token-inexistant")

    assert_response :gone
  end

  test "le telechargement redirige vers le stockage et compte le passage" do
    transfer = create_transfer

    get download_transfer_path(transfer.token)

    assert_response :redirect
    assert_equal 1, transfer.reload.download_count
    assert_not_nil transfer.last_downloaded_at
  end

  test "le telechargement d'un lien expire ne compte pas" do
    transfer = create_transfer(expires_at: 1.minute.ago)

    get download_transfer_path(transfer.token)

    assert_response :gone
    assert_equal 0, transfer.reload.download_count
  end

  test "l'API cree un transfert a partir d'un blob deja televerse" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("contenu de test"),
      filename: "dossier.pdf",
      content_type: "application/pdf"
    )

    sign_in_owner
    post api_file_transfers_path, params: { file: blob.signed_id, label: "Dossier" }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "dossier.pdf", body["file_name"]
    assert_match %r{/t/#{body['token']}\z}, body["share_url"]
  end

  test "l'API borne la duree de retention demandee" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("contenu de test"),
      filename: "dossier.pdf",
      content_type: "application/pdf"
    )

    sign_in_owner
    post api_file_transfers_path, params: { file: blob.signed_id, retention_days: 999 }

    assert_response :created
    assert_in_delta 30.days.from_now, FileTransfer.last.expires_at, 1.minute
  end
end
