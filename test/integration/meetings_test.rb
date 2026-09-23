require "test_helper"

class MeetingsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  def audio_blob(content_type: "audio/mp4", filename: "reunion.m4a")
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("fake audio"), filename: filename, content_type: content_type,
                                           identify: false)
  end

  test "cree une reunion a partir d'un blob deja envoye et enfile le traitement" do
    assert_enqueued_jobs 1, only: MeetingProcessJob do
      post api_meetings_path, params: { meeting: { title: "Point bail", kind: "visio", participants: "Marie" },
                                        audio: audio_blob.signed_id }, headers: ACCEPT_JSON
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["in_progress"]
    meeting = Meeting.find(body["id"])
    assert meeting.audio.attached?
    assert_equal "visio", meeting.kind
    assert_not_nil meeting.held_at
  end

  test "refuse une reunion sans enregistrement ou avec un fichier qui n'est pas de l'audio" do
    post api_meetings_path, params: { meeting: { title: "Sans audio" } }, headers: ACCEPT_JSON
    assert_response :unprocessable_entity

    post api_meetings_path, params: { meeting: { title: "PDF" }, audio: audio_blob(content_type: "application/pdf", filename: "x.pdf").signed_id },
                            headers: ACCEPT_JSON
    assert_response :unprocessable_entity
    assert_equal 0, Meeting.count
  end

  test "nomme les intervenants puis regenere la synthese" do
    meeting = create(:meeting, :transcribed, status: "done", summary: { "overview" => "ancien" })

    patch api_meeting_path(meeting), params: { meeting: { speaker_names: { speaker_1: " Sylvain ", speaker_2: "Marie" } } },
                                     headers: ACCEPT_JSON
    assert_response :success
    labels = JSON.parse(response.body)["speakers"].map { |s| s["label"] }
    assert_equal %w[Sylvain Marie], labels

    assert_enqueued_jobs 1, only: MeetingProcessJob do
      post regenerate_api_meeting_path(meeting), headers: ACCEPT_JSON
    end
    assert_response :success
    assert_equal({}, meeting.reload.summary)
  end

  test "refuse une regeneration pendant un traitement" do
    meeting = create(:meeting, :transcribed, status: "running", requested_at: Time.current)

    post regenerate_api_meeting_path(meeting), headers: ACCEPT_JSON

    assert_response :conflict
  end

  test "supprimer la reunion garde le compte rendu dans les documents" do
    document = Document.create!(domain: "meetings", name: "Reunion - test",
                                file: { io: StringIO.new("%PDF-1.4"), filename: "r.pdf", content_type: "application/pdf" })
    meeting = create(:meeting, :transcribed, status: "done", document: document)

    delete api_meeting_path(meeting), headers: ACCEPT_JSON

    assert_response :no_content
    assert Document.exists?(document.id)
  end

  test "la liste et le detail exigent d'etre connecte" do
    sign_out :user
    get api_meetings_path, headers: ACCEPT_JSON

    assert_response :unauthorized
  end

  def chunk_upload(body = "webm-data", content_type: "audio/webm;codecs=opus")
    Rack::Test::UploadedFile.new(StringIO.new(body), content_type, original_filename: "chunk.webm")
  end

  test "enregistrement en direct : ouverture, morceaux idempotents, fin" do
    post api_meetings_path, params: { recording: true, meeting: { kind: "visio" } }, headers: ACCEPT_JSON
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "recording", body["status"]
    assert_match(/\ARéunion du /, body["title"])
    meeting = Meeting.find(body["id"])

    2.times { post chunks_api_meeting_path(meeting), params: { chunk: chunk_upload, part: 1, seq: 0 }, headers: ACCEPT_JSON }
    post chunks_api_meeting_path(meeting), params: { chunk: chunk_upload, part: 1, seq: 1 }, headers: ACCEPT_JSON
    assert_response :success
    assert_equal 2, JSON.parse(response.body).dig("recording", "chunks")

    assert_enqueued_jobs 1, only: MeetingProcessJob do
      post finish_api_meeting_path(meeting), headers: ACCEPT_JSON
    end
    assert_response :success
    assert meeting.reload.in_progress?

    # Une fois termine, plus aucun morceau n'est accepte.
    post chunks_api_meeting_path(meeting), params: { chunk: chunk_upload, part: 1, seq: 2 }, headers: ACCEPT_JSON
    assert_response :conflict
  end

  test "refuse un morceau qui n'est pas de l'audio ou mal numerote" do
    meeting = create(:meeting, status: "recording")

    post chunks_api_meeting_path(meeting), params: { chunk: chunk_upload(content_type: "application/pdf"), part: 1, seq: 0 }, headers: ACCEPT_JSON
    assert_response :unprocessable_entity
    post chunks_api_meeting_path(meeting), params: { chunk: chunk_upload, part: 0, seq: 0 }, headers: ACCEPT_JSON
    assert_response :unprocessable_entity
    assert_not meeting.reload.audio_chunks.attached?
  end

  test "terminer un enregistrement vide est refuse, regenerer pendant l'enregistrement aussi" do
    meeting = create(:meeting, status: "recording")

    post finish_api_meeting_path(meeting), headers: ACCEPT_JSON
    assert_response :unprocessable_entity
    post regenerate_api_meeting_path(meeting), headers: ACCEPT_JSON
    assert_response :conflict
  end
end

