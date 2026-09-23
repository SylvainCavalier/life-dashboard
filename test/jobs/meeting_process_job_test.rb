require "test_helper"
require "minitest/mock"

class MeetingProcessJobTest < ActiveJob::TestCase
  class FakeTranscriber
    attr_reader :calls

    def initialize(error: nil)
      @error = error
      @calls = 0
    end

    def transcribe_with_speakers(**)
      @calls += 1
      raise @error if @error

      { segments: FactoryBot.build(:meeting, :transcribed).transcript, duration: 15 }
    end
  end

  class FakeSummarizer
    def initialize(names = {})
      @names = names
    end

    def call
      { content: { "overview" => "Synthese de test.", "key_points" => [], "decisions" => [], "action_items" => [], "open_questions" => [] },
        model: "claude-test", speaker_names: @names }
    end
  end

  def run_job(meeting, transcriber: FakeTranscriber.new, summarizer: FakeSummarizer.new)
    Transcription.stub(:default, transcriber) do
      Meetings::Summarizer.stub(:new, ->(*) { summarizer }) do
        MeetingProcessJob.perform_now(meeting.id)
      end
    end
    meeting.reload
  end

  test "transcrit, supprime l'audio, resume et range le PDF dans les documents" do
    meeting = create(:meeting, :with_audio, speaker_names: { "speaker_1" => "Sylvain" })
    meeting.update!(status: "pending", requested_at: Time.current)

    run_job(meeting, summarizer: FakeSummarizer.new("speaker_1" => "Jean", "speaker_2" => "Marie"))

    assert meeting.done?, meeting.error
    assert_not meeting.audio.attached?
    assert_equal 3, meeting.transcript.size
    assert_equal 15, meeting.duration_seconds
    assert_equal "Synthese de test.", meeting.summary["overview"]
    # Un nom saisi par Sylvain n'est jamais remplace par une supposition du modele.
    assert_equal({ "speaker_1" => "Sylvain", "speaker_2" => "Marie" }, meeting.speaker_names)

    document = meeting.document
    assert_equal "meetings", document.domain
    assert_equal "in_person", document.category
    assert_equal "Synthese de test.", document.notes
    assert_equal "application/pdf", document.file.content_type
  end

  test "une regeneration remplace le PDF du meme document sans retranscrire" do
    meeting = create(:meeting, :with_audio)
    meeting.update!(status: "pending", requested_at: Time.current)
    run_job(meeting)
    document_id = meeting.document_id

    transcriber = FakeTranscriber.new
    meeting.regenerate!
    run_job(meeting, transcriber: transcriber)

    assert meeting.done?
    assert_equal 0, transcriber.calls
    assert_equal document_id, meeting.document_id
    assert_equal 1, Document.where(domain: "meetings").count
  end

  test "un echec de transcription est consigne et l'audio est garde pour la relance" do
    meeting = create(:meeting, :with_audio)
    meeting.update!(status: "pending", requested_at: Time.current)

    run_job(meeting, transcriber: FakeTranscriber.new(error: Transcription::Error.new("Voxtral 500")))

    assert meeting.failed?
    assert_equal "Voxtral 500", meeting.error
    assert meeting.audio.attached?
    assert_nil meeting.document
  end

  test "ne fait rien sur une reunion qui n'est pas en attente" do
    meeting = create(:meeting, :transcribed, status: "done")
    transcriber = FakeTranscriber.new

    run_job(meeting, transcriber: transcriber)

    assert_equal 0, transcriber.calls
    assert_nil meeting.document
  end

  # Transcripteur qui renvoie un segment par appel et note le contenu recu.
  class RecordingTranscriber
    attr_reader :bodies

    def initialize
      @bodies = []
    end

    def transcribe_with_speakers(io:, **)
      @bodies << io.read
      { segments: [{ "speaker" => "speaker_1", "start" => 1.0, "end" => 4.0, "text" => "Partie #{@bodies.size}" }], duration: 60 }
    end
  end

  test "enregistrement en direct : recolle les morceaux de chaque partie et enchaine les horodatages" do
    meeting = create(:meeting, status: "recording")
    { [1, 0] => "AA", [1, 1] => "BB", [2, 0] => "CC" }.each do |(part, seq), body|
      meeting.audio_chunks.attach(io: StringIO.new(body), filename: Meeting.chunk_filename(part, seq, "audio/webm"),
                                  content_type: "audio/webm")
    end
    meeting.update!(status: "pending", requested_at: Time.current)
    transcriber = RecordingTranscriber.new

    run_job(meeting, transcriber: transcriber)

    assert meeting.done?, meeting.error
    assert_equal %w[AABB CC], transcriber.bodies
    assert_equal [["speaker_1", 1.0], ["p2_speaker_1", 61.0]], meeting.transcript.map { |s| [s["speaker"], s["start"]] }
    assert_equal 120, meeting.duration_seconds
    assert_not meeting.audio_chunks.attached?
  end
end

