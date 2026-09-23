require "test_helper"

class Meetings::SummarizerTest < ActiveSupport::TestCase
  # Client Anthropic factice : renvoie un message dont le texte est le JSON donne.
  class FakeClient
    Block = Struct.new(:type, :text)
    Message = Struct.new(:content, :stop_reason, :model)

    attr_reader :params

    def initialize(json, stop_reason: :end_turn)
      @json = json
      @stop_reason = stop_reason
    end

    def messages = self

    def create(**params)
      @params = params
      Message.new([Block.new(:text, @json.to_json)], @stop_reason, "claude-test")
    end
  end

  SUMMARY = {
    "overview" => "Point sur le bail.", "key_points" => [], "decisions" => [],
    "action_items" => [], "open_questions" => [],
    "speakers" => [{ "speaker" => "speaker_2", "name" => "Marie" }, { "speaker" => "speaker_9", "name" => "Fantome" },
                   { "speaker" => "speaker_1", "name" => nil }]
  }.freeze

  test "renvoie la synthese et ne garde que les noms d'intervenants existants" do
    client = FakeClient.new(SUMMARY)
    result = Meetings::Summarizer.new(build(:meeting, :transcribed), client: client).call

    assert_equal "Point sur le bail.", result[:content]["overview"]
    assert_not result[:content].key?("speakers")
    assert_equal({ "speaker_2" => "Marie" }, result[:speaker_names])
    assert_equal "claude-test", result[:model]
    assert_equal :json_schema, client.params.dig(:output_config, :format_, :type)
    assert_match "[speaker_2] J'envoie", client.params[:messages].first[:content]
    assert_match "mardi 2026-09-22 à 10:00", client.params[:messages].first[:content]
  end

  test "une synthese tronquee est une erreur" do
    client = FakeClient.new(SUMMARY, stop_reason: :max_tokens)

    assert_raises(Meetings::Summarizer::Error) { Meetings::Summarizer.new(build(:meeting, :transcribed), client: client).call }
  end
end
