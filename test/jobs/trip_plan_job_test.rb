require "test_helper"
require "minitest/mock"

class TripPlanJobTest < ActiveJob::TestCase
  FakeService = Struct.new(:result) do
    def call
      raise result if result.is_a?(Exception)

      result
    end
  end

  def with_service(result, &)
    Trips::PlanGenerationService.stub(:new, ->(*) { FakeService.new(result) }, &)
  end

  def content(total: 2_000.0)
    { "summary" => "OK", "costs" => { "total_eur" => total }, "places" => [], "restaurants" => [], "itinerary" => [] }
  end

  test "un plan en attente est genere et passe en done" do
    trip = create(:trip)
    plan = create(:trip_plan, :pending, trip: trip)

    with_service({ content: content, model: "gpt-test" }) do
      TripPlanJob.perform_now(plan.id)
    end

    plan.reload
    assert_equal "done", plan.status
    assert_equal "gpt-test", plan.model
    assert_equal 2_000.0, plan.estimated_total_eur
    assert_equal "OK", plan.content["summary"]
    assert_equal trip.plan_fingerprint, plan.input_fingerprint
    assert plan.generated_at.present?
    assert_nil plan.error
  end

  test "un echec passe le plan en failed et conserve l'ancien rapport" do
    plan = create(:trip_plan)
    plan.update!(status: "pending", requested_at: Time.current)

    with_service(Trips::PlanGenerationService::EmptyResponse.new("Réponse vide")) do
      TripPlanJob.perform_now(plan.id)
    end

    plan.reload
    assert_equal "failed", plan.status
    assert_includes plan.error, "Réponse vide"
    assert_equal "Le Japon au printemps.", plan.content["summary"]
  end

  test "une erreur HTTP OpenAI est enregistree avec le libelle de l'API" do
    plan = create(:trip_plan, :pending)
    api_error = OpenAI::Errors::RateLimitError.new(
      url: URI("https://api.openai.com/v1/responses"), status: 429, headers: {},
      body: { error: { message: "You have no credits remaining.", code: "credit_balance_exhausted" } },
      request: nil, response: nil
    )

    with_service(api_error) do
      TripPlanJob.perform_now(plan.id)
    end

    plan.reload
    assert_equal "failed", plan.status
    assert_equal "OpenAI (HTTP 429) : You have no credits remaining.", plan.error
  end

  test "un plan qui n'est plus en attente n'est pas retraite" do
    plan = create(:trip_plan)
    called = false

    Trips::PlanGenerationService.stub(:new, lambda { |*|
      called = true
      FakeService.new({ content: content, model: "x" })
    }) do
      TripPlanJob.perform_now(plan.id)
    end

    assert_not called
    assert_equal "done", plan.reload.status
  end

  test "un plan supprime entre-temps est ignore" do
    assert_nothing_raised do
      TripPlanJob.perform_now(999_999)
    end
  end
end
