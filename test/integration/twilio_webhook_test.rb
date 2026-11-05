require "test_helper"
require "minitest/mock"

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

  test "liste blanche ouverte : un inconnu est admis, repond et notifie, comme temporaire" do
    AlfredSetting.instance.open_sms_whitelist!
    pushes = []

    PushNotifications.stub(:broadcast, ->(payload) { pushes << payload; 1 }) do
      assert_enqueued_with(job: SmsReplyJob) { deliver(sms(from: "+33699999945", body: "Bonjour, ici Karim")) }
    end

    assert_response :success
    person = SmsCorrespondent.for_phone("+33699999945")
    assert person.temporary?
    assert_equal "Inconnu 9945", person.name
    assert_equal "Bonjour, ici Karim", person.messages.last.body
    assert_includes pushes.first[:body], "Bonjour, ici Karim"
  end

  test "au bout de 24 h la liste se referme seule, y compris pour les numeros admis" do
    AlfredSetting.instance.open_sms_whitelist!
    deliver(sms(from: "+33699999945", sid: "SM1"))
    @friend_count = SmsMessage.count

    travel(AlfredSetting::SMS_OPENING_DURATION + 1.minute) do
      assert_no_difference("SmsMessage.count") do
        deliver(sms(from: "+33699999945", sid: "SM2"))
        deliver(sms(from: "+33688888888", sid: "SM3"))
      end
      assert_response :success
      assert_nil SmsCorrespondent.for_phone("+33688888888")

      deliver(sms(sid: "SM4"))
      assert_equal "SM4", @friend.messages.last.twilio_sid
    end
  end

  test "la reactivation manuelle ferme aussi la porte aux numeros admis" do
    AlfredSetting.instance.open_sms_whitelist!
    deliver(sms(from: "+33699999945", sid: "SM1"))
    AlfredSetting.instance.close_sms_whitelist!

    assert_no_difference("SmsMessage.count") { deliver(sms(from: "+33699999945", sid: "SM2")) }
  end

  test "un numero garde reste accepte apres la fermeture" do
    AlfredSetting.instance.open_sms_whitelist!
    deliver(sms(from: "+33699999945", sid: "SM1"))
    SmsCorrespondent.for_phone("+33699999945").update!(temporary: false)
    AlfredSetting.instance.close_sms_whitelist!

    assert_difference("SmsMessage.count") { deliver(sms(from: "+33699999945", sid: "SM2")) }
  end

  test "liste blanche ouverte : un numero desactive et un expediteur sans numero restent ignores" do
    AlfredSetting.instance.open_sms_whitelist!
    @friend.update!(enabled: false)

    assert_no_difference(["SmsMessage.count", "SmsCorrespondent.count"]) do
      deliver(sms(sid: "SM1"))
      assert_response :success
      deliver(sms(from: "MABANQUE", sid: "SM2"))
      assert_response :success
    end
  end

  test "le nombre d'inconnus admis par ouverture est plafonne" do
    AlfredSetting.instance.open_sms_whitelist!
    SmsCorrespondent::MAX_TEMPORARY_PER_OPENING.times do |i|
      SmsCorrespondent.create!(name: "Inconnu #{i}", phone: format("+336000000%02d", i), temporary: true)
    end

    assert_no_difference("SmsCorrespondent.count") { deliver(sms(from: "+33699999945")) }
    assert_response :success
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
