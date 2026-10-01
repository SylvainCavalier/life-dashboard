require "test_helper"

class VideoTranscripts::SummarizerTest < ActiveSupport::TestCase
  FakeClient = Meetings::SummarizerTest::FakeClient

  SUMMARY = {
    "overview" => "Une interview.", "chapters" => [{ "start" => "00:00:00", "title" => "Accueil", "summary" => "Salutations." }],
    "key_points" => [], "claims" => [],
    "speakers" => [{ "speaker" => "speaker_2", "name" => "Sylvain" }, { "speaker" => "speaker_7", "name" => "Fantome" }]
  }.freeze

  test "renvoie le resume et ne garde que les noms d'intervenants existants" do
    client = FakeClient.new(SUMMARY)
    transcript = build(:video_transcript, :transcribed, language: "uk", source_citation: "« Titre », Chaine (YouTube)")

    result = VideoTranscripts::Summarizer.new(transcript, client: client).call

    assert_equal "Une interview.", result[:content]["overview"]
    assert_not result[:content].key?("speakers")
    assert_equal({ "speaker_2" => "Sylvain" }, result[:speaker_names])
    prompt = client.params[:messages].first[:content]
    assert_match "[speaker_1] Добрий день!", prompt
    assert_match "Langue indiquée : Ukrainien", prompt
    assert_match "« Titre », Chaine (YouTube)", prompt
  end

  test "une transcription vide n'est pas envoyee au modele" do
    assert_raises(VideoTranscripts::Summarizer::Error) do
      VideoTranscripts::Summarizer.new(build(:video_transcript), client: FakeClient.new(SUMMARY)).call
    end
  end
end
