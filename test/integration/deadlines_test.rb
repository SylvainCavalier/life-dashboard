require "test_helper"

class DeadlinesTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
    travel_to Time.zone.local(2026, 10, 12, 10, 0)
  end
  teardown { travel_back }

  test "creation : occurrences dans l'agenda et dans la liste chronologique" do
    post api_deadlines_path, params: { deadline: { title: "Charges copro", category: "charges", due_on: "2026-01-01",
                                                   recurrence: "quarterly", amount: "320.50" } }.to_json, headers: JSON_HEADERS
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "2027-01-01", json["next_on"]
    assert_equal "320,50 €", json["formatted_amount"]

    assert_equal 4, Event.where(event_type: "echeance").count

    get api_deadlines_path, headers: JSON_HEADERS
    upcoming = JSON.parse(response.body)["upcoming"]
    assert_equal(%w[2027-01-01 2027-04-01 2027-07-01 2027-10-01], upcoming.map { |o| o["date"] })
  end

  test "creation refusee sans date" do
    post api_deadlines_path, params: { deadline: { title: "URSSAF" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "modification et suppression" do
    deadline = create(:deadline)

    patch api_deadline_path(deadline), params: { deadline: { title: "Taxe foncière Créteil" } }.to_json,
                                       headers: JSON_HEADERS
    assert_response :success
    assert_equal ["Taxe foncière Créteil"], deadline.events.pluck(:title).uniq

    delete api_deadline_path(deadline), headers: JSON_HEADERS
    assert_response :no_content
    assert_equal 0, Event.count
  end
end
