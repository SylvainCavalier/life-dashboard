require "test_helper"

class VideoTranscriptsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  def video_blob(content_type: "video/mp4", filename: "interview.mp4")
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("fake video"), filename: filename, content_type: content_type,
                                           identify: false)
  end

  def local_download
    create(:video_download, :completed).tap do |download|
      FileUtils.mkdir_p(download.local_dir)
      File.write(download.local_filepath, "fake video")
    end
  end

  test "cree une transcription a partir d'un blob deja envoye et enfile le traitement" do
    assert_enqueued_jobs 1, only: VideoTranscriptJob do
      post api_video_transcripts_path, params: { video_transcript: { title: "Interview", language: "ru" }, video: video_blob.signed_id },
                                       headers: ACCEPT_JSON
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["in_progress"]
    transcript = VideoTranscript.find(body["id"])
    assert transcript.video.attached?
    assert_equal "ru", transcript.language
  end

  test "refuse une transcription sans video ou avec un fichier qui n'est pas une video" do
    post api_video_transcripts_path, params: { video_transcript: { title: "Rien" } }, headers: ACCEPT_JSON
    assert_response :unprocessable_entity

    post api_video_transcripts_path, params: { video_transcript: { title: "PDF" },
                                               video: video_blob(content_type: "application/pdf", filename: "x.pdf").signed_id },
                                     headers: ACCEPT_JSON
    assert_response :unprocessable_entity
    assert_equal 0, VideoTranscript.count
  end

  test "transcrit un telechargement du Downloader, liste parmi les sources disponibles" do
    download = local_download
    create(:video_download, :completed) # fichier absent du disque : pas proposable

    get sources_api_video_transcripts_path, headers: ACCEPT_JSON
    assert_equal [download.id], JSON.parse(response.body).map { |s| s["id"] }

    assert_enqueued_jobs 1, only: VideoTranscriptJob do
      post api_video_transcripts_path, params: { video_transcript: { language: "auto" }, video_download_id: download.id },
                                       headers: ACCEPT_JSON
    end
    assert_response :created
    assert_equal ["Downloader", "Une video"], JSON.parse(response.body).values_at("source", "title")
  end

  test "PDF a la demande et rangement dans les documents une fois transcrite" do
    pending_one = create(:video_transcript, :with_video)
    get pdf_api_video_transcript_path(pending_one)
    assert_response :conflict

    transcript = create(:video_transcript, :transcribed, status: "done")
    get pdf_api_video_transcript_path(transcript)
    assert_response :success
    assert_equal "application/pdf", response.media_type

    post save_to_documents_api_video_transcript_path(transcript), headers: ACCEPT_JSON
    assert_response :success
    assert_equal "transcriptions", transcript.reload.document.domain
    assert JSON.parse(response.body).dig("document", "download_url")
  end

  test "nommer un intervenant met a jour le PDF deja range" do
    transcript = create(:video_transcript, :transcribed, status: "done")
    document = transcript.save_to_documents!
    checksum = document.file.blob.checksum

    patch api_video_transcript_path(transcript), params: { video_transcript: { speaker_names: { speaker_1: " Olena " } } },
                                                 headers: ACCEPT_JSON

    assert_response :success
    assert_equal({ "speaker_1" => "Olena" }, transcript.reload.speaker_names)
    assert_not_equal checksum, document.reload.file.blob.checksum
  end

  test "supprimer une transcription garde le document" do
    transcript = create(:video_transcript, :transcribed, status: "done")
    transcript.save_to_documents!

    assert_no_difference -> { Document.count } do
      delete api_video_transcript_path(transcript), headers: ACCEPT_JSON
    end
    assert_response :no_content
  end
end
