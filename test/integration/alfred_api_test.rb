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

  test "la page Alfred lit et modifie les sections du prompt" do
    sign_in_owner

    get "/api/alfred", headers: JSON_HEADERS
    assert_response :success
    body = response.parsed_body
    assert_equal Alfred::Prompt::SECTIONS.map { |s| s[:key] }, body["prompt_sections"].map { |s| s["key"] }
    assert_nil body["prompt_sections"].first["override"]
    assert_equal Alfred::Tools::ALL.size, body["tools"].size
    assert_includes body["readable_models"], "Contact"
    assert_not_includes body["readable_models"], "PasswordEntry"

    patch "/api/alfred", params: { prompt_overrides: { tone: "Sobre et bref." } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "Sobre et bref.", response.parsed_body["prompt_sections"].find { |s| s["key"] == "tone" }["override"]
    assert_equal "Sobre et bref.", AlfredSetting.instance.override_for("tone")

    get "/api/alfred/prompt", headers: JSON_HEADERS
    assert_includes response.parsed_body["text"], "## Ton\nSobre et bref."

    patch "/api/alfred", params: { prompt_overrides: { tone: nil } }.to_json, headers: JSON_HEADERS
    assert_nil AlfredSetting.instance.override_for("tone")

    patch "/api/alfred", params: { prompt_overrides: { hack: "x" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_content
  end

  test "une conversation s'exporte en PDF et se vide" do
    sign_in_owner
    conversation = AlfredConversation.create!(title: "Test")
    conversation.messages.create!(role: "user", content: "Bonjour")
    conversation.messages.create!(role: "assistant", content: "Bonjour, Monsieur.")

    get "/api/alfred_conversations/#{conversation.id}/export"
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF")

    assert_difference "AlfredMessage.count", -2 do
      delete "/api/alfred_conversations/#{conversation.id}", headers: JSON_HEADERS
    end
    assert_response :no_content
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
