require "test_helper"
require "minitest/mock"

class VideoDownloadJobTest < ActiveJob::TestCase
  include VideoDownloadStorageHelper

  # Remplace yt-dlp : ecrit un faux fichier dans le repertoire demande, ou leve.
  class FakeService
    def initialize(output_dir:, error: nil)
      @output_dir = output_dir.to_s
      @error = error
    end

    def call
      raise @error if @error

      FileUtils.mkdir_p(@output_dir)
      filepath = File.join(@output_dir, "Ma video [abc123].mp4")
      File.write(filepath, "faux contenu video")
      VideoDownloads::YtDlpService::Result.new(
        filepath: filepath, title: "Ma video", filename: File.basename(filepath),
        file_size: File.size(filepath), thumbnail_url: "https://i.ytimg.com/vi/abc123/hq.jpg",
        description: "Description", duration: 42,
        platform: "Youtube", canonical_url: "https://www.youtube.com/watch?v=abc123", uploader: "Une chaine",
        uploader_handle: "@unechaine", uploader_url: "https://www.youtube.com/@unechaine",
        published_at: Time.utc(2024, 1, 2), view_count: 1500
      )
    end
  end

  def with_service(error: nil, &)
    factory = ->(output_dir:, **) { FakeService.new(output_dir: output_dir, error: error) }
    VideoDownloads::YtDlpService.stub(:new, factory, &)
  end

  test "un telechargement local est complete et garde son fichier sur le disque" do
    download = create(:video_download)

    with_service { VideoDownloadJob.perform_now(download.id) }

    download.reload
    assert download.completed?
    assert_equal "Ma video", download.title
    assert_equal "Ma video [abc123].mp4", download.filename
    assert_equal 42, download.duration
    assert_equal "Une chaine", download.uploader
    assert_equal "Youtube", download.platform
    assert_equal Time.utc(2024, 1, 2), download.published_at
    assert_equal 1500, download.view_count
    assert_includes download.citation, "Une chaine (Youtube), publié le 02/01/2024"
    assert download.completed_at.present?
    assert File.exist?(download.local_filepath)
    assert_not download.file.attached?
    assert download.file_available?
  end

  test "un telechargement cloud est attache via Active Storage et quitte le disque" do
    folder = create(:video_folder, name: "Conferences")
    download = create(:video_download, :cloud, video_folder: folder)

    with_service { VideoDownloadJob.perform_now(download.id) }

    download.reload
    assert download.completed?
    assert download.file.attached?
    assert_equal "video/mp4", download.file.content_type
    assert_equal "video_downloads/conferences/#{download.id}-ma-video-abc123.mp4", download.file.key
    assert_equal "faux contenu video", download.file.download
    assert_not File.exist?(download.local_dir)
  ensure
    download&.file&.purge
  end

  test "un echec passe le telechargement en failed et nettoie le disque" do
    download = create(:video_download)
    FileUtils.mkdir_p(download.local_dir)

    with_service(error: VideoDownloads::YtDlpService::Error.new("yt-dlp a echoue : Video unavailable")) do
      assert_nothing_raised { VideoDownloadJob.perform_now(download.id) }
    end

    download.reload
    assert download.failed?
    assert_includes download.error_message, "Video unavailable"
    assert_not File.exist?(download.local_dir)
  end

  test "un telechargement deja traite n'est pas relance" do
    download = create(:video_download, :completed)

    VideoDownloads::YtDlpService.stub(:new, ->(**) { flunk "yt-dlp ne doit pas etre appele" }) do
      VideoDownloadJob.perform_now(download.id)
    end

    assert download.reload.completed?
  end

  test "un telechargement supprime entre-temps est ignore" do
    assert_nothing_raised { VideoDownloadJob.perform_now(0) }
  end
end
