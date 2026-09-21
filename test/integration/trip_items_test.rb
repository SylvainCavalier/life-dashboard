require "test_helper"

class TripItemsTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze

  setup do
    sign_in_owner
    @trip = create(:trip)
  end

  test "creation d'un item de planning" do
    assert_difference "TripItem.count", 1 do
      post api_trip_trip_items_path(@trip),
           params: { trip_item: { day: @trip.start_date, kind: "hotel", title: "Ryokan", url: "https://example.com",
                                  start_time: "15:00", cost: 120 } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "hotel", body["kind"]
    assert_equal "15:00", body["start_time"]
    assert_equal "120.0", body["cost"]
    assert_equal 0, body["position"]
  end

  test "un jour hors des dates du voyage repond 422" do
    post api_trip_trip_items_path(@trip),
         params: { trip_item: { day: @trip.end_date + 3, title: "Trop tard" } }.to_json,
         headers: JSON_HEADERS
    assert_response :unprocessable_entity
    assert_includes JSON.parse(response.body)["errors"].join, "compris"
  end

  test "mise a jour et suppression" do
    item = create(:trip_item, trip: @trip)

    patch api_trip_trip_item_path(@trip, item),
          params: { trip_item: { title: "Nouveau titre", kind: "restaurant" } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "Nouveau titre", JSON.parse(response.body)["title"]

    assert_difference "TripItem.count", -1 do
      delete api_trip_trip_item_path(@trip, item), headers: { "Accept" => "application/json" }
    end
    assert_response :no_content
  end

  test "un item d'un autre voyage est introuvable" do
    other = create(:trip, destination: "Rome", country_code: "it")
    item = create(:trip_item, trip: other)

    delete api_trip_trip_item_path(@trip, item), headers: { "Accept" => "application/json" }
    assert_response :not_found
    assert TripItem.exists?(item.id)
  end
end
