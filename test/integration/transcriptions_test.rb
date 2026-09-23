require "test_helper"

class TranscriptionsTest < ActionDispatch::IntegrationTest
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  # Voxtral factice : la suite ne parle jamais a Mistral.
  class FakeTranscriber
    attr_reader :calls

    def initialize(result = nil, &block)
      @result = result
      @block = block
      @calls = []
    end

    def transcribe(**kwargs)
      @calls << kwargs
      @block ? @block.call : @result
    end
  end

  setup { sign_in_owner }

  test "transcrit un enregistrement webm (Chrome)" do
    fake = FakeTranscriber.new("Rappeler le notaire mardi.")
    Transcription.stub(:default, fake) do
      post api_transcriptions_path, params: { audio: audio_upload("audio/webm;codecs=opus", "dictee.webm") }, headers: ACCEPT_JSON
    end

    assert_response :success
    assert_equal "Rappeler le notaire mardi.", JSON.parse(response.body)["text"]
    assert_equal "audio/webm", fake.calls.first[:content_type]
    assert_equal "dictee.webm", fake.calls.first[:filename]
  end

  test "accepte le mp4 de Safari" do
    Transcription.stub(:default, FakeTranscriber.new("Bonjour")) do
      post api_transcriptions_path, params: { audio: audio_upload("audio/mp4", "dictee.m4a") }, headers: ACCEPT_JSON
    end

    assert_response :success
  end

  test "refuse un fichier qui n'est pas de l'audio" do
    fake = FakeTranscriber.new("jamais")
    Transcription.stub(:default, fake) do
      post api_transcriptions_path, params: { audio: audio_upload("application/pdf", "note.pdf") }, headers: ACCEPT_JSON
    end

    assert_response :unprocessable_entity
    assert_empty fake.calls
  end

  test "503 quand la cle Mistral manque" do
    fake = FakeTranscriber.new { raise Transcription::NotConfigured, "MISTRAL_API_KEY manquante" }
    Transcription.stub(:default, fake) do
      post api_transcriptions_path, params: { audio: audio_upload("audio/webm", "dictee.webm") }, headers: ACCEPT_JSON
    end

    assert_response :service_unavailable
  end

  test "502 quand Voxtral echoue" do
    fake = FakeTranscriber.new { raise Transcription::Error, "Voxtral 500" }
    Transcription.stub(:default, fake) do
      post api_transcriptions_path, params: { audio: audio_upload("audio/webm", "dictee.webm") }, headers: ACCEPT_JSON
    end

    assert_response :bad_gateway
  end

  test "exige d'etre connecte" do
    sign_out :user
    post api_transcriptions_path, params: { audio: audio_upload("audio/webm", "dictee.webm") }, headers: ACCEPT_JSON

    assert_response :unauthorized
  end

  private

  def audio_upload(content_type, filename)
    Rack::Test::UploadedFile.new(StringIO.new("\x1A\x45\xDF\xA3" + "0" * 2000), content_type, original_filename: filename)
  end
end
