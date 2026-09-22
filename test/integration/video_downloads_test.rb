require "test_helper"
require "minitest/mock"

class VideoDownloadsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include VideoDownloadStorageHelper

  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  # --- Telechargements ---

  test "la creation enfile le job et repond 201" do
    assert_enqueued_with(job: VideoDownloadJob) do
      post api_video_downloads_path,
           params: { video_download: { url: "https://youtu.be/abc", format: "mp4",
                                       quality: "720p", storage: "local" } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :created

    body = JSON.parse(response.body)
    assert_equal "pending", body["status"]
    assert_equal "720p", body["quality"]
    assert_nil body["file_url"]
  end

  test "la creation accepte un extrait en timecodes" do
    post api_video_downloads_path,
         params: { video_download: { url: "https://youtu.be/abc", format: "mp4", quality: "720p", storage: "local",
                                     clip_start: "0:34", clip_end: "0:47" } }.to_json,
         headers: JSON_HEADERS
    assert_response :created

    body = JSON.parse(response.body)
    assert_equal [ 34, 47, "0:34 - 0:47" ], body.values_at("clip_start", "clip_end", "clip_label")
  end

  test "un extrait incoherent repond 422" do
    assert_no_enqueued_jobs do
      post api_video_downloads_path,
           params: { video_download: { url: "https://youtu.be/abc", format: "mp3", storage: "local",
                                       clip_start: "0:47", clip_end: "0:34" } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :unprocessable_content
    assert_includes JSON.parse(response.body)["errors"].join, "apres son debut"
  end

  test "un statut envoye par le client est ignore" do
    post api_video_downloads_path,
         params: { video_download: { url: "https://youtu.be/abc", format: "mp3", storage: "local",
                                     status: "completed" } }.to_json,
         headers: JSON_HEADERS
    assert_response :created
    assert_equal "pending", VideoDownload.last.status
  end

  test "une demande invalide repond 422 sans rien enfiler" do
    assert_no_enqueued_jobs do
      post api_video_downloads_path,
           params: { video_download: { url: "pas-une-url", format: "mp4", storage: "local" } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :unprocessable_content
    assert JSON.parse(response.body)["errors"].any?
  end

  test "l'index filtre par statut et par dossier" do
    folder = create(:video_folder)
    in_folder = create(:video_download, :cloud, :completed, video_folder: folder)
    create(:video_download, :failed)

    get api_video_downloads_path, params: { video_folder_id: folder.id }, headers: ACCEPT_JSON
    assert_equal [ in_folder.id ], JSON.parse(response.body).map { |d| d["id"] }

    get api_video_downloads_path, params: { status: "failed" }, headers: ACCEPT_JSON
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_includes body.first["error_message"], "yt-dlp"
  end

  test "un fichier local termine est renvoye en piece jointe" do
    download = create(:video_download, :completed)
    FileUtils.mkdir_p(download.local_dir)
    File.write(download.local_filepath, "contenu video")

    get api_video_download_path(download), headers: ACCEPT_JSON
    assert_equal file_api_video_download_path(download), JSON.parse(response.body)["file_url"]

    get file_api_video_download_path(download)
    assert_response :success
    assert_equal "contenu video", response.body
    assert_match "attachment", response.headers["Content-Disposition"]

    get file_api_video_download_path(download), params: { disposition: "inline" }
    assert_match "inline", response.headers["Content-Disposition"]
  end

  test "un fichier cloud redirige vers l'URL du stockage" do
    download = create(:video_download, :cloud, :completed)
    download.file.attach(io: StringIO.new("contenu"), filename: download.filename, content_type: "video/mp4")

    get file_api_video_download_path(download)
    assert_response :redirect
  ensure
    download&.file&.purge
  end

  test "un fichier disparu ou un telechargement inacheve repond 410" do
    gone = create(:video_download, :completed)
    get file_api_video_download_path(gone), headers: ACCEPT_JSON
    assert_response :gone

    get file_api_video_download_path(create(:video_download)), headers: ACCEPT_JSON
    assert_response :gone
  end

  test "la suppression efface l'enregistrement et le fichier local" do
    download = create(:video_download, :completed)
    FileUtils.mkdir_p(download.local_dir)
    File.write(download.local_filepath, "contenu video")

    assert_difference "VideoDownload.count", -1 do
      delete api_video_download_path(download), headers: ACCEPT_JSON
    end
    assert_response :no_content
    assert_not File.exist?(download.local_dir)
  end

  test "availability signale les binaires manquants" do
    VideoDownloads::YtDlpService.stub(:missing_binaries, [ "yt-dlp" ]) do
      get availability_api_video_downloads_path, headers: ACCEPT_JSON
    end
    assert_response :success
    assert_equal({ "available" => false, "missing_binaries" => [ "yt-dlp" ] }, JSON.parse(response.body))
  end

  # --- Dossiers ---

  test "cycle de vie d'un dossier" do
    post api_video_folders_path, params: { video_folder: { name: "Musique" } }.to_json, headers: JSON_HEADERS
    assert_response :created
    folder = VideoFolder.find(JSON.parse(response.body)["id"])
    download = create(:video_download, :cloud, video_folder: folder)

    get api_video_folders_path, headers: ACCEPT_JSON
    assert_equal 1, JSON.parse(response.body).first["downloads_count"]

    patch api_video_folder_path(folder), params: { video_folder: { name: "Concerts" } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "Concerts", folder.reload.name

    delete api_video_folder_path(folder), headers: ACCEPT_JSON
    assert_response :no_content
    assert_nil download.reload.video_folder_id
  end

  test "un nom de dossier en double repond 422" do
    create(:video_folder, name: "Musique")

    post api_video_folders_path, params: { video_folder: { name: "musique" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_content
  end
end
