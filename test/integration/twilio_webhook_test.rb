require "test_helper"

class TwilioWebhookTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  TOKEN = "jeton-de-test".freeze
  URL = "http://www.example.com/webhooks/twilio/sms".freeze

  setup do
    @previous = ENV["TWILIO_AUTH_TOKEN"]
    ENV["TWILIO_AUTH_TOKEN"] = TOKEN
    @friend = SmsCorrespondent.create!(name: "Camille", phone: "+33612345678")
  end

  teardown { ENV["TWILIO_AUTH_TOKEN"] = @previous }

  def signature(params, token: TOKEN)
    data = URL + params.sort.map { |k, v| "#{k}#{v}" }.join
    Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", token, data))
  end

  def deliver(params, signed_with: TOKEN)
    post "/webhooks/twilio/sms", params: params, headers: { "X-Twilio-Signature" => signature(params, token: signed_with) }
  end

  def sms(from: "+33612345678", sid: "SM1", body: "Bonjour Alfred")
    { "From" => from, "To" => "+33900000000", "Body" => body, "MessageSid" => sid }
  end

  test "un texto d'un numero autorise est consigne et sa reponse enfilee" do
    assert_enqueued_with(job: SmsReplyJob) { deliver(sms) }

    assert_response :success
    assert_includes response.media_type, "xml"
    message = @friend.messages.last
    assert_equal "Bonjour Alfred", message.body
    assert_equal "inbound", message.direction
    assert_equal "received", message.status
  end

  test "sans session mais avec signature : pas de redirection vers la connexion" do
    deliver(sms)
    assert_response :success
  end

  test "une signature invalide ou absente est refusee" do
    assert_no_difference("SmsMessage.count") do
      deliver(sms, signed_with: "mauvais-jeton")
      assert_response :forbidden

      post "/webhooks/twilio/sms", params: sms
      assert_response :forbidden
    end
  end

  test "sans jeton configure, tout est refuse" do
    ENV["TWILIO_AUTH_TOKEN"] = nil
    assert_no_difference("SmsMessage.count") { deliver(sms) }
    assert_response :forbidden
  end

  test "un numero inconnu est ignore, sans reponse ni job" do
    assert_no_enqueued_jobs do
      assert_no_difference("SmsMessage.count") { deliver(sms(from: "+33699999999")) }
    end
    assert_response :success
    assert_not_includes response.body, "Message"
  end

  test "un correspondant desactive est ignore" do
    @friend.update!(enabled: false)
    assert_no_difference("SmsMessage.count") { deliver(sms) }
    assert_response :success
  end

  test "un webhook rejoue n'est traite qu'une fois" do
    deliver(sms)
    assert_no_enqueued_jobs(only: SmsReplyJob) do
      assert_no_difference("SmsMessage.count") { deliver(sms) }
    end
    assert_response :success
  end

  test "le corps est chiffre en base" do
    deliver(sms)
    raw = SmsMessage.connection.select_value("SELECT body FROM sms_messages ORDER BY id DESC LIMIT 1")
    assert_not_includes raw, "Bonjour Alfred"
  end
end
