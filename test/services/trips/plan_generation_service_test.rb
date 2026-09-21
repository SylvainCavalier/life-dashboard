require "test_helper"

class Trips::PlanGenerationServiceTest < ActiveSupport::TestCase
  # Faux client OpenAI : capture les arguments de responses.create et renvoie
  # une reponse dont la forme imite celle du SDK (output -> message -> output_text.parsed).
  class FakeClient
    attr_reader :captured

    def initialize(response)
      @response = response
    end

    def responses
      self
    end

    def create(**kwargs)
      @captured = kwargs
      @response
    end
  end

  def parsed_payload
    {
      "summary" => "Résumé", "history" => "Histoire",
      "practical_info" => [], "rules" => [],
      "costs" => { "flights_eur" => 800.0, "lodging_per_night_eur" => 90.0, "food_per_day_eur" => 40.0,
                   "activities_eur" => 100.0, "total_eur" => 1_500.0, "local_currency" => "JPY",
                   "exchange_rate_note" => "1 EUR = 160 JPY", "assumptions" => [] },
      "places" => [], "restaurants" => [], "itinerary" => [], "sources" => []
    }
  end

  def message_with(*contents)
    OpenAI::Models::Responses::ResponseOutputMessage.new(
      id: "msg_1", content: contents, role: :assistant, status: :completed, type: :message
    )
  end

  def output_text(parsed)
    OpenAI::Models::Responses::ResponseOutputText.new(annotations: [], text: parsed.to_json, type: :output_text,
                                                      parsed: parsed)
  end

  def search_call
    OpenAI::Models::Responses::ResponseFunctionWebSearch.new(id: "ws_1", action: { type: :search, query: "test" },
                                                             status: :completed, type: :web_search_call)
  end

  def with_env(vars)
    previous = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    previous.each { |k, v| ENV[k] = v }
  end

  def response_with(*output)
    Struct.new(:output, :model).new(output, "gpt-test")
  end

  test "construit la requete avec recherche web, schema structure et prix en euros" do
    trip = build(:trip, destination: "Kyoto", notes: "Pas de sushi")
    client = FakeClient.new(response_with(search_call, message_with(output_text(parsed_payload))))

    result = Trips::PlanGenerationService.new(trip, client: client).call

    assert_equal "gpt-test", result[:model]
    assert_equal 1_500.0, result[:content].dig("costs", "total_eur")

    args = client.captured
    assert_equal Trips::TripPlanSchema, args[:text]
    assert_equal "web_search", args[:tools].first[:type]
    assert_equal "Paris", args[:tools].first[:user_location][:city]
    assert_includes args[:instructions], "EUROS"
    assert_includes args[:instructions], "EXACTEMENT #{trip.duration_days} jour"
    assert_includes args[:input], "Kyoto"
    assert_includes args[:input], "Pas de sushi"
    assert_includes args[:input], "2 voyageur"
  end

  test "le modele par defaut est surchargeable par OPENAI_TRIP_MODEL" do
    client = FakeClient.new(response_with(message_with(output_text(parsed_payload))))
    with_env("OPENAI_TRIP_MODEL" => "gpt-custom") do
      Trips::PlanGenerationService.new(build(:trip), client: client).call
    end
    assert_equal "gpt-custom", client.captured[:model]
  end

  test "une reponse sans contenu structure leve EmptyResponse" do
    client = FakeClient.new(response_with(search_call))
    assert_raises(Trips::PlanGenerationService::EmptyResponse) do
      Trips::PlanGenerationService.new(build(:trip), client: client).call
    end
  end

  test "un refus du modele leve EmptyResponse avec le motif" do
    refusal = OpenAI::Models::Responses::ResponseOutputRefusal.new(refusal: "Non", type: :refusal)
    client = FakeClient.new(response_with(message_with(refusal)))
    error = assert_raises(Trips::PlanGenerationService::EmptyResponse) do
      Trips::PlanGenerationService.new(build(:trip), client: client).call
    end
    assert_includes error.message, "Non"
  end
end
