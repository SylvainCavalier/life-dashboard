require "test_helper"
require "minitest/mock"

class VideoTranscriptJobTest < ActiveJob::TestCase
  class FakeTranscriber
    attr_reader :calls, :languages, :content_types

    def initialize(error: nil)
      @error = error
      @calls = 0
      @languages = []
      @content_types = []
    end

    def transcribe_with_speakers(io:, filename:, content_type:, language:)
      @calls += 1
      @languages << language
      @content_types << content_type
      raise @error if @error

      { segments: FactoryBot.build(:video_transcript, :transcribed).transcript, duration: 12 }
    end
  end

  class FakeSummarizer
    def initialize(names = {})
      @names = names
    end

    def call
      { content: { "overview" => "Resume de test.", "chapters" => [], "key_points" => [], "claims" => [] },
        model: "claude-test", speaker_names: @names }
    end
  end

  # ffmpeg n'est pas suppose present sur la machine de test : le fichier part tel quel.
  def run_job(transcript, transcriber: FakeTranscriber.new, summarizer: FakeSummarizer.new)
    VideoTranscripts::AudioExtractor.stub(:available?, false) do
      Transcription.stub(:default, transcriber) do
        VideoTranscripts::Summarizer.stub(:new, ->(*) { summarizer }) do
          VideoTranscriptJob.perform_now(transcript.id)
        end
      end
    end
    transcript.reload
  end

  def queued(transcript)
    transcript.update!(status: "pending", requested_at: Time.current)
    transcript
  end

  test "transcrit dans la langue choisie, supprime la video importee et resume" do
    transcript = queued(create(:video_transcript, :with_video, language: "uk", speaker_names: { "speaker_2" => "Sylvain" }))
    transcriber = FakeTranscriber.new

    run_job(transcript, transcriber: transcriber, summarizer: FakeSummarizer.new("speaker_1" => "Olena", "speaker_2" => "Jean"))

    assert transcript.done?, transcript.error
    assert_equal ["uk"], transcriber.languages
    assert_equal ["video/mp4"], transcriber.content_types
    assert_not transcript.video.attached?
    assert transcript.transcribed?
    assert_equal 12, transcript.duration_seconds
    assert_equal "Resume de test.", transcript.summary["overview"]
    # Un nom saisi par Sylvain n'est jamais remplace par une supposition du modele.
    assert_equal({ "speaker_1" => "Olena", "speaker_2" => "Sylvain" }, transcript.speaker_names)
    # Rien n'est range dans les documents sans le demander.
    assert_nil transcript.document
  end

  test "ne touche pas au fichier d'un telechargement du Downloader" do
    download = create(:video_download, :completed)
    FileUtils.mkdir_p(download.local_dir)
    File.write(download.local_filepath, "fake video")
    transcript = queued(VideoTranscript.build_from_download(download).tap(&:save!))
    transcriber = FakeTranscriber.new

    run_job(transcript, transcriber: transcriber)

    assert transcript.done?, transcript.error
    assert_equal [nil], transcriber.languages
    assert File.exist?(download.local_filepath)
  end

  test "un nouveau resume ne retranscrit pas et met a jour le document deja range" do
    transcript = queued(create(:video_transcript, :with_video))
    run_job(transcript)
    document = transcript.save_to_documents!

    transcriber = FakeTranscriber.new
    transcript.regenerate!
    run_job(transcript, transcriber: transcriber)

    assert transcript.done?
    assert_equal 0, transcriber.calls
    assert_equal document.id, transcript.document_id
    assert_equal 1, Document.where(domain: "transcriptions").count
  end

  test "un echec de transcription est consigne et la video est gardee pour la relance" do
    transcript = queued(create(:video_transcript, :with_video))

    run_job(transcript, transcriber: FakeTranscriber.new(error: Transcription::Error.new("Voxtral 500 : boom")))

    assert transcript.failed?
    assert_equal "Voxtral 500 : boom", transcript.error
    assert transcript.video.attached?
    assert_not transcript.transcribed?
  end

  test "une video sans parole se termine sans resume" do
    transcript = queued(create(:video_transcript, :with_video))
    silent = FakeTranscriber.new
    def silent.transcribe_with_speakers(**) = { segments: [], duration: 30 }

    run_job(transcript, transcriber: silent)

    assert transcript.done?
    assert transcript.transcribed?
    assert_equal({}, transcript.summary)
  end
end
