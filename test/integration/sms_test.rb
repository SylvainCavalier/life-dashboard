require "test_helper"
require "minitest/mock"

class SmsTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze

  setup do
    @sent = []
    TwilioSms.transport = lambda do |to:, body:|
      @sent << { to: to, body: body }
      "SM1"
    end
  end

  teardown { TwilioSms.transport = nil }

  test "le proprietaire gere la liste blanche, le numero est normalise" do
    sign_in_owner
    post "/api/sms_correspondents", params: { sms_correspondent: { name: "Camille", phone: "06 12 34 56 78" } }.to_json, headers: JSON_HEADERS
    assert_response :created
    assert_equal "+33612345678", SmsCorrespondent.last.phone

    post "/api/sms_correspondents", params: { sms_correspondent: { name: "Doublon", phone: "+33612345678" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_content
    post "/api/sms_correspondents", params: { sms_correspondent: { name: "Faux", phone: "abc" } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_content

    get "/api/sms", headers: JSON_HEADERS
    assert_equal ["Camille"], response.parsed_body["correspondents"].map { |c| c["name"] }
  end

  test "tous les contacts sont proposes, meme sans numero, et un numero se lie a une fiche" do
    sign_in_owner
    contact = Contact.create!(first_name: "Camille", last_name: "Durand", relationship_type: "copine")

    get "/api/sms", headers: JSON_HEADERS
    option = response.parsed_body["contacts"].find { |c| c["id"] == contact.id }
    assert_equal "Durand Camille", option["label"]
    assert_equal "Camille Durand", option["name"]
    assert_nil option["phone"]

    friend = SmsCorrespondent.create!(name: "Camille", phone: "+33612345678")
    patch "/api/sms_correspondents/#{friend.id}", params: { sms_correspondent: { contact_id: contact.id } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_equal "la copine de Sylvain", friend.reload.relation

    patch "/api/sms_correspondents/#{friend.id}", params: { sms_correspondent: { contact_id: 0 } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_content

    patch "/api/sms_correspondents/#{friend.id}", params: { sms_correspondent: { contact_id: nil } }.to_json, headers: JSON_HEADERS
    assert_nil friend.reload.contact_id
  end

  test "envoi manuel, consigne dans le fil" do
    sign_in_owner
    friend = SmsCorrespondent.create!(name: "Camille", phone: "+33612345678")

    post "/api/sms_correspondents/#{friend.id}/send_text", params: { body: "Bonjour" }.to_json, headers: JSON_HEADERS

    assert_response :created
    assert_equal [{ to: "+33612345678", body: "Bonjour" }], @sent
    assert_equal "Bonjour", response.parsed_body.last["body"]
  end

  test "un echec Twilio est note et remonte" do
    sign_in_owner
    TwilioSms.transport = ->(to:, body:) { raise TwilioSms::Error, "Twilio 21610 : refuse (#{to} #{body.size})" }
    friend = SmsCorrespondent.create!(name: "Camille", phone: "+33612345678")

    post "/api/sms_correspondents/#{friend.id}/send_text", params: { body: "Bonjour" }.to_json, headers: JSON_HEADERS

    assert_response :bad_gateway
    assert_equal "failed", friend.messages.last.status
  end

  test "les faits : anniversaire sans annee par defaut, texte libre ensuite, vide = defaut" do
    sign_in_owner
    PersonalProfile.create!(first_name: "S", last_name: "B", email: "s@example.com", birth_date: Date.new(1985, 3, 14))

    get "/api/sms", headers: JSON_HEADERS
    assert_includes response.parsed_body["facts"], "14/03"
    assert_not_includes response.parsed_body["facts"], "1985"

    patch "/api/sms", params: { facts: "Il aime le the." }.to_json, headers: JSON_HEADERS
    assert_equal "Il aime le the.", response.parsed_body["facts"]

    patch "/api/sms", params: { facts: "" }.to_json, headers: JSON_HEADERS
    assert_includes response.parsed_body["facts"], "s@example.com"
  end

  test "un compte d'ami n'a pas acces a la page Textos" do
    friend_user = User.create!(email: "ami@example.com", password: "mot-de-passe-solide", role: "friend")
    sign_in friend_user
    get "/api/sms", headers: JSON_HEADERS
    assert_response :forbidden
  end

  test "propose_sms impose d'ecrire en tant qu'Alfred et donne de quoi s'adresser a la personne" do
    description = Alfred::Tools::ProposeSms.definition[:description]
    assert_includes description, "en ton nom"
    assert_includes description, "troisieme personne"

    contact = Contact.create!(first_name: "Brendan", last_name: "Durand", gender: "homme", relationship_type: "ami")
    linked = SmsCorrespondent.create!(name: "Brendan D.", phone: "+33612345670", contact: contact)
    assert_equal ["Brendan", "homme", "un(e) ami(e) de Sylvain"], [linked.first_name, linked.gender, linked.relation]

    conversation = AlfredConversation.create!
    message = conversation.messages.create!(role: "assistant", status: "processing", content: "")
    context = Alfred::Tools::Context.new(conversation: conversation, message: message, seen: Set.new)
    result, error = Alfred::Tools.run("query_records", { "model" => "SmsCorrespondent" }, context)
    assert_not error
    assert_equal "homme", result[:records].first["gender"]

    unlinked = SmsCorrespondent.new(name: "Sam Martin", phone: "+33612345671")
    assert_equal "Sam", unlinked.first_name
    assert_nil unlinked.gender
  end

  test "propose_sms ne part qu'a la confirmation, et seulement a un correspondant autorise" do
    ENV["TWILIO_ACCOUNT_SID"] = "AC"
    ENV["TWILIO_AUTH_TOKEN"] = "t"
    ENV["TWILIO_PHONE_NUMBER"] = "+33900000000"
    friend = SmsCorrespondent.create!(name: "Camille", phone: "+33612345678")
    conversation = AlfredConversation.create!
    message = conversation.messages.create!(role: "assistant", status: "processing", content: "")
    context = Alfred::Tools::Context.new(conversation: conversation, message: message, seen: Set.new)

    _, error = Alfred::Tools.run("propose_sms", { "correspondent_id" => friend.id, "body" => "Bonjour", "summary" => "x" }, context)
    assert_not error
    assert_empty @sent

    Alfred::ActionExecutor.new(AlfredAction.last).confirm!
    assert_equal "executed", AlfredAction.last.status
    assert_equal "Bonjour", @sent.last[:body]

    result, error = Alfred::Tools.run("propose_sms", { "correspondent_id" => 0, "body" => "x", "summary" => "x" }, context)
    assert error
    assert result[:error]
  ensure
    %w[TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_PHONE_NUMBER].each { |key| ENV.delete(key) }
  end
end
