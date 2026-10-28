require "test_helper"

# Comptes d'amis : seules les pages Outils, Downloader et Transfert leur sont ouvertes,
# et ils n'y voient que leurs propres enregistrements. Ces tests sont la pour qu'un
# controleur ajoute plus tard reste ferme aux amis sans rien faire.
class FriendAccessTest < ActionDispatch::IntegrationTest
  include VideoDownloadStorageHelper

  FRIEND_CONTROLLERS = %w[
    api/video_downloads api/video_folders api/file_transfers api/video_transcripts
  ].freeze

  setup do
    @owner = create(:user)
    @friend = create(:user, :friend)
    sign_in @friend
  end

  test "toutes les routes API reservees repondent 403 a un ami" do
    paths = Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.delete_suffix("(.:format)")
      next unless route.verb == "GET" && path.start_with?("/api/") && !path.include?(":")
      next if FRIEND_CONTROLLERS.include?(route.defaults[:controller])
      # Route declaree sans action dans le controleur (resources :companies et son /new) : 404 avant tout filtre.
      next unless "#{route.defaults[:controller]}_controller".camelize.constantize.action_methods.include?(route.defaults[:action])

      path
    end
    assert paths.size > 20, "la liste des routes a verifier semble vide"

    paths.each do |path|
      get path, headers: { "Accept" => "application/json" }
      assert_response :forbidden, "#{path} devrait etre refuse a un ami"
    end
  end

  test "les ecritures reservees sont refusees" do
    assert_no_difference "Contact.count" do
      post "/api/contacts", params: { contact: { first_name: "Ami", last_name: "Curieux" } }.to_json,
                            headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    end
    assert_response :forbidden
  end

  test "une page reservee renvoie vers les outils, les pages ouvertes s'affichent" do
    %w[/ /contacts /documents /tools-pas-un-outil].each do |path|
      get path
      assert_redirected_to "/tools", "#{path} devrait renvoyer vers les outils"
    end

    %w[/tools /tools/pdf /downloader /downloader/folders/1 /transfer /account/password].each do |path|
      get path
      assert_response :success, "#{path} devrait s'afficher"
    end

    get "/tools"
    assert_match 'name="dashboard-role" content="friend"', response.body
  end

  test "un ami ne voit que ses telechargements" do
    mine = create(:video_download, :completed, user: @friend)
    owners = create(:video_download, :completed, user: @owner)

    get "/api/video_downloads", headers: { "Accept" => "application/json" }
    assert_equal [mine.id], response.parsed_body.map { |download| download["id"] }

    get "/api/video_downloads/#{owners.id}", headers: { "Accept" => "application/json" }
    assert_response :not_found

    assert_no_difference "VideoDownload.count" do
      delete "/api/video_downloads/#{owners.id}", headers: { "Accept" => "application/json" }
    end
    assert_response :not_found
  end

  test "un telechargement cree par un ami lui appartient, sans dossier d'autrui" do
    owners_folder = create(:video_folder, user: @owner)

    post "/api/video_downloads", params: { video_download: { url: "https://youtu.be/abc", format: "mp3", storage: "cloud",
                                                             video_folder_id: owners_folder.id } },
                                 as: :json
    assert_response :unprocessable_content

    post "/api/video_downloads", params: { video_download: { url: "https://youtu.be/abc", format: "mp3", storage: "local" } }, as: :json
    assert_response :created
    assert_equal @friend, VideoDownload.find(response.parsed_body["id"]).user
  end

  test "les dossiers sont propres a chaque compte, meme nom compris" do
    create(:video_folder, name: "Conferences", user: @owner)

    post "/api/video_folders", params: { video_folder: { name: "Conferences" } }, as: :json
    assert_response :created

    get "/api/video_folders", headers: { "Accept" => "application/json" }
    assert_equal [@friend.id], response.parsed_body.map { |folder| VideoFolder.find(folder["id"]).user_id }
  end

  test "un ami ne voit que ses transferts" do
    owners = FileTransfer.new(user: @owner)
    owners.file.attach(io: StringIO.new("prive"), filename: "bail.pdf", content_type: "application/pdf")
    owners.save!

    get "/api/file_transfers", headers: { "Accept" => "application/json" }
    assert_empty response.parsed_body

    assert_no_difference "FileTransfer.count" do
      delete "/api/file_transfers/#{owners.id}", headers: { "Accept" => "application/json" }
    end
    assert_response :not_found
  end

  test "outil Videos : transcriptions et sources limitees a l'ami, pas de rangement dans les documents" do
    owners_download = create(:video_download, :completed, user: @owner)
    owners_transcript = create(:video_transcript, :transcribed, user: @owner)
    mine = create(:video_transcript, :transcribed, user: @friend)

    get "/api/video_transcripts", headers: { "Accept" => "application/json" }
    assert_equal [mine.id], response.parsed_body.map { |transcript| transcript["id"] }

    get "/api/video_transcripts/sources", headers: { "Accept" => "application/json" }
    assert_empty response.parsed_body

    get "/api/video_transcripts/#{owners_transcript.id}", headers: { "Accept" => "application/json" }
    assert_response :not_found

    post "/api/video_transcripts", params: { video_download_id: owners_download.id }, as: :json
    assert_response :not_found

    assert_no_difference "Document.count" do
      post "/api/video_transcripts/#{mine.id}/save_to_documents", headers: { "Accept" => "application/json" }
    end
    assert_response :forbidden
  end

  test "le proprietaire ne voit pas les telechargements d'un ami" do
    create(:video_download, :completed, user: @friend)
    sign_in @owner

    get "/api/video_downloads", headers: { "Accept" => "application/json" }
    assert_empty response.parsed_body
  end

  test "Alfred ne lit que les donnees du proprietaire" do
    create(:video_download, :completed, user: @friend)
    owners = create(:video_download, :completed, user: @owner)

    assert_equal [owners.id], Alfred::DataAccess.readable_relation("VideoDownload").pluck(:id)
  end

  test "un ami peut se deconnecter" do
    delete destroy_user_session_path
    assert_response :redirect

    get "/api/video_downloads", headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end
end

class FriendAccountTest < ActiveSupport::TestCase
  test "sans mot de passe fourni, il est provisoire et doit etre change ; fourni, il est garde tel quel" do
    provisional, password = User.create_friend!(email: "un@example.test")
    assert provisional.must_change_password?
    assert provisional.valid_password?(password)

    chosen, = User.create_friend!(email: "deux@example.test", password: "Treize-caract")
    assert_not chosen.must_change_password?
    assert chosen.friend?

    assert_raises(ActiveRecord::RecordInvalid) { User.create_friend!(email: "trois@example.test", password: "a" * 12) }
  end
end
