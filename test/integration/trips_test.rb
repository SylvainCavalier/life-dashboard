require "test_helper"

class TripsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  test "l'index liste les voyages avec leurs attributs derives" do
    upcoming = create(:trip)
    past = create(:trip, :past)
    create(:trip, :past, :cancelled, country_code: "it")
    create(:trip_plan, trip: past)

    get api_trips_path, headers: { "Accept" => "application/json" }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 3, body.size

    json_upcoming = body.find { |t| t["id"] == upcoming.id }
    assert_equal false, json_upcoming["past"]
    assert_equal false, json_upcoming["visited"]
    assert_nil json_upcoming["plan_status"]
    assert_equal 8, json_upcoming["duration_days"]

    json_past = body.find { |t| t["id"] == past.id }
    assert_equal true, json_past["visited"]
    assert_equal "done", json_past["plan_status"]
    assert_equal "1850.0", json_past["estimated_total_eur"]
    assert_nil json_past["plan"], "l'index ne renvoie pas le rapport complet"
  end

  test "creation d'un voyage" do
    assert_difference "Trip.count", 1 do
      post api_trips_path,
           params: { trip: { destination: "Lisbonne", country_code: "PT", start_date: "2027-05-01",
                             end_date: "2027-05-05", travelers: 2 } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "pt", body["country_code"]
    assert_equal 5, body["duration_days"]
    assert_equal "envisage", body["status"]
    assert_equal "Paris", body["departure_city"]
    assert_nil body["plan"]
    assert_equal [], body["items"]
  end

  test "un voyage invalide repond 422" do
    post api_trips_path,
         params: { trip: { destination: "Lisbonne", country_code: "pt", start_date: "2027-05-05",
                           end_date: "2027-05-01" } }.to_json,
         headers: JSON_HEADERS
    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"].join, "postérieure"

    post api_trips_path,
         params: { trip: { destination: "Lisbonne", country_code: "PRT", start_date: "2027-05-01",
                           end_date: "2027-05-05" } }.to_json,
         headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "show renvoie le rapport et les items tries" do
    trip = create(:trip)
    create(:trip_plan, trip: trip)
    late = create(:trip_item, trip: trip, title: "Soir", start_time: "20:00")
    early = create(:trip_item, trip: trip, title: "Matin", start_time: "09:30")
    no_time = create(:trip_item, trip: trip, title: "Sans heure")
    next_day = create(:trip_item, trip: trip, title: "Lendemain", day: trip.start_date + 1)

    get api_trip_path(trip), headers: { "Accept" => "application/json" }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "done", body["plan"]["status"]
    assert_equal false, body["plan"]["outdated"]
    assert_equal "Le Japon au printemps.", body["plan"]["content"]["summary"]
    assert_equal([early.id, late.id, no_time.id, next_day.id], body["items"].map { |i| i["id"] })
    assert_equal "09:30", body["items"].first["start_time"]
  end

  test "show ne renvoie pas le contenu d'un rapport en cours" do
    trip = create(:trip)
    create(:trip_plan, :running, trip: trip, requested_at: 1.minute.ago)

    get api_trip_path(trip), headers: { "Accept" => "application/json" }
    body = JSON.parse(response.body)
    assert_equal "running", body["plan"]["status"]
    assert_nil body["plan"]["content"]
    assert_equal false, body["plan"]["stuck"]
  end

  test "mise a jour et suppression" do
    trip = create(:trip)
    create(:trip_plan, trip: trip)

    patch api_trip_path(trip), params: { trip: { travelers: 3 } }.to_json, headers: JSON_HEADERS
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 3, body["travelers"]
    assert_equal true, body["plan"]["outdated"], "le rapport est signale obsolete"

    assert_difference ["Trip.count", "TripPlan.count"], -1 do
      delete api_trip_path(trip), headers: { "Accept" => "application/json" }
    end
    assert_response :no_content
  end

  test "un voyage inconnu repond 404" do
    get api_trip_path(999_999), headers: { "Accept" => "application/json" }
    assert_response :not_found
  end

  test "POST /plan enfile la generation et ne la double pas" do
    trip = create(:trip)

    assert_enqueued_with(job: TripPlanJob) do
      post plan_api_trip_path(trip), headers: JSON_HEADERS
    end
    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "pending", body["status"]
    assert_nil body["content"]

    assert_no_enqueued_jobs do
      post plan_api_trip_path(trip), headers: JSON_HEADERS
    end
    assert_response :accepted
    assert_equal body["id"], JSON.parse(response.body)["id"]
    assert_equal 1, TripPlan.where(trip: trip).count
  end

  test "POST /plan relance un plan bloque" do
    trip = create(:trip)
    create(:trip_plan, :running, trip: trip, requested_at: 30.minutes.ago)

    assert_enqueued_with(job: TripPlanJob) do
      post plan_api_trip_path(trip), headers: JSON_HEADERS
    end
    assert_equal "pending", JSON.parse(response.body)["status"]
  end
end
