require "test_helper"

class AlfredApiTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze

  test "Alfred est ferme sans session" do
    conversation = AlfredConversation.create!
    action = conversation.actions.create!(operation: "create", target_model: "Note", summary: "x",
                                          payload: { attributes: { title: "Intrus", content: "x" }, before: {} }.to_json)

    get "/api/alfred", headers: JSON_HEADERS
    assert_response :unauthorized
    get "/api/alfred_conversations/#{conversation.id}", headers: JSON_HEADERS
    assert_response :unauthorized

    assert_no_enqueued_jobs do
      post "/api/alfred_conversations/#{conversation.id}/message", params: { content: "Bonjour" }.to_json, headers: JSON_HEADERS
    end
    assert_response :unauthorized

    assert_no_difference "Note.count" do
      post "/api/alfred_actions/#{action.id}/confirm", headers: JSON_HEADERS
    end
    assert_response :unauthorized
  end

  test "un message enfile la reponse et verrouille la conversation" do
    sign_in_owner
    conversation = AlfredConversation.create!

    with_keys do
      assert_enqueued_with(job: AlfredReplyJob) do
        post "/api/alfred_conversations/#{conversation.id}/message", params: { content: "Mes rendez-vous ?" }.to_json, headers: JSON_HEADERS
      end
      assert_response :created
      body = response.parsed_body
      assert body["busy"]
      assert_equal %w[user assistant], body["messages"].map { |m| m["role"] }
      assert_equal "Mes rendez-vous ?", conversation.reload.title

      post "/api/alfred_conversations/#{conversation.id}/message", params: { content: "Encore" }.to_json, headers: JSON_HEADERS
      assert_response :conflict
    end
  end

  test "sans cles API, Alfred se declare indisponible" do
    sign_in_owner
    conversation = AlfredConversation.create!

    with_keys(anthropic: nil) do
      get "/api/alfred", headers: JSON_HEADERS
      assert_equal false, response.parsed_body["available"]
      assert_includes response.parsed_body["missing_keys"], "ANTHROPIC_API_KEY"

      assert_no_enqueued_jobs do
        post "/api/alfred_conversations/#{conversation.id}/message", params: { content: "Bonjour" }.to_json, headers: JSON_HEADERS
      end
      assert_response :service_unavailable
    end
  end

  test "la confirmation d'une proposition passe par l'API" do
    sign_in_owner
    conversation = AlfredConversation.create!
    action = conversation.actions.create!(operation: "create", target_model: "Note", summary: "Nouvelle note",
                                          payload: { attributes: { title: "Courses", content: "Pain" }, before: {} }.to_json)

    assert_difference "Note.count", 1 do
      post "/api/alfred_actions/#{action.id}/confirm", headers: JSON_HEADERS
    end
    assert_response :success
    assert_equal "executed", response.parsed_body["status"]

    post "/api/alfred_actions/#{action.id}/confirm", headers: JSON_HEADERS
    assert_response :conflict
  end

  private

  def with_keys(anthropic: "test-key", mistral: "test-key")
    previous = ENV.to_h.slice("ANTHROPIC_API_KEY", "MISTRAL_API_KEY")
    { "ANTHROPIC_API_KEY" => anthropic, "MISTRAL_API_KEY" => mistral }.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
    yield
  ensure
    %w[ANTHROPIC_API_KEY MISTRAL_API_KEY].each { |k| previous[k] ? ENV[k] = previous[k] : ENV.delete(k) }
  end
end
