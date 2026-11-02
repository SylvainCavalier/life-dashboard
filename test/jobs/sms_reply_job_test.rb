require "test_helper"
require "minitest/mock"

class SmsReplyJobTest < ActiveSupport::TestCase
  # Client Claude factice : rejoue une liste de reponses et garde les requetes.
  class FakeClient
    Block = Struct.new(:type, :text, :name, :input, :id, keyword_init: true)
    Response = Struct.new(:content, :stop_reason, keyword_init: true)
    attr_reader :requests

    def initialize(*responses)
      @responses = responses
      @requests = []
    end

    def messages = self

    def create(**params)
      @requests << params.merge(messages: params[:messages].dup)
      @responses.shift
    end
  end

  def text_response(text)
    FakeClient::Response.new(content: [FakeClient::Block.new(type: :text, text: text)], stop_reason: :end_turn)
  end

  setup do
    @sent = []
    TwilioSms.transport = lambda do |to:, body:|
      @sent << { to: to, body: body }
      "SM#{@sent.size}"
    end
    @friend = SmsCorrespondent.create!(name: "Camille", phone: "+33612345678")
    @inbound = @friend.messages.create!(direction: "inbound", status: "received", body: "Quel est son mail ?")
  end

  teardown { TwilioSms.transport = nil }

  # Fait tourner le job avec un agent branche sur le client factice.
  def perform(client, message = @inbound)
    Alfred::Sms::Agent.stub(:new, ->(inbound) { Alfred::Sms::Agent.allocate.tap { |a| a.send(:initialize, inbound, client: client) } }) do
      SmsReplyJob.perform_now(message.id)
    end
  end

  test "repond par texto et consigne la reponse" do
    perform(FakeClient.new(text_response("Son adresse est a@b.fr.")))

    assert_equal [{ to: "+33612345678", body: "Son adresse est a@b.fr." }], @sent
    assert_equal "answered", @inbound.reload.status
    outbound = @friend.messages.where(direction: "outbound").last
    assert_equal "sent", outbound.status
    assert_equal "SM1", outbound.twilio_sid
  end

  test "l'agent n'a que ses trois outils et les seuls faits autorises" do
    PersonalProfile.create!(first_name: "S", last_name: "Nom-Administratif", email: "s@example.com", birth_date: Date.new(1985, 3, 14),
                            passport_number: "PASS123", iban: "FR7600000")
    AlfredMemory.create!(content: "Souvenir prive", category: "other")
    client = FakeClient.new(text_response("Bien."))
    perform(client)

    request = client.requests.first
    assert_equal %w[get_availability notify_sylvain propose_to_sylvain], request[:tools].map { |t| t[:name] }
    system = request[:system_].map { |b| b[:text] }.join("\n")
    assert_includes system, "s@example.com"
    assert_includes system, "14/03"
    assert_not_includes system, "1985"
    assert_no_match(/Nom-Administratif|PASS123|FR7600000|Souvenir prive/, system)
  end

  test "une fiche liee donne la relation, et rien d'autre de la fiche" do
    contact = Contact.create!(first_name: "Camille", last_name: "Durand", relationship_type: "copine",
                              notes: "Note privee", likes: "Gout prive", address: "Adresse privee")
    @friend.update!(contact: contact)
    client = FakeClient.new(text_response("Bien."))
    perform(client)

    system = client.requests.first[:system_].map { |b| b[:text] }.join("\n")
    assert_includes system, "(prénom : Camille), la copine de Sylvain"
    assert_includes system, "sans jamais dire comment cette personne est classée"
    assert_includes system, "le plus affectueux"
    assert_no_match(/Note privee|Gout prive|Adresse privee/, system)
    assert_equal %w[get_availability notify_sylvain propose_to_sylvain], client.requests.first[:tools].map { |t| t[:name] }
  end

  test "sans fiche, seul le nom est donne" do
    client = FakeClient.new(text_response("Bien."))
    perform(client)

    assert_includes client.requests.first[:system_].map { |b| b[:text] }.join("\n"), "Ton correspondant : Camille."
  end

  test "execute un outil puis repond" do
    tool_use = FakeClient::Block.new(type: :tool_use, name: "get_availability", id: "t1",
                                     input: { "from_date" => Date.current.iso8601, "to_date" => Date.current.iso8601 })
    client = FakeClient.new(FakeClient::Response.new(content: [tool_use], stop_reason: :tool_use), text_response("Il est libre."))
    perform(client)

    assert_equal "Il est libre.", @sent.last[:body]
    result = client.requests.last[:messages].last[:content].first
    assert_equal "t1", result[:tool_use_id]
    assert_not result[:is_error]
  end

  test "un outil inconnu du modele (query_records) est refuse" do
    result, error = Alfred::Sms::Tools.run("query_records", { "model" => "PasswordEntry" }, correspondent: @friend, inbound: @inbound)

    assert error
    assert_match "Outil inconnu", result[:error]
  end

  test "une panne du modele donne un texto d'excuse" do
    failing = Object.new
    def failing.messages = self
    def failing.create(**) = raise("panne")
    perform(failing)

    assert_equal "failed", @inbound.reload.status
    assert_equal SmsReplyJob::APOLOGY, @sent.last[:body]
  end

  test "ne repond pas deux fois au meme texto" do
    perform(FakeClient.new(text_response("Une fois."), text_response("Deux fois.")))
    perform(FakeClient.new(text_response("Deux fois.")))

    assert_equal 1, @sent.size
  end

  test "dans une rafale, seul le dernier texto repond, avec tout l'historique" do
    second = @friend.messages.create!(direction: "inbound", status: "received", body: "Et son anniversaire ?")
    client = FakeClient.new(text_response("Voici."))

    perform(client, @inbound)
    assert_equal "merged", @inbound.reload.status
    assert_empty @sent

    perform(client, second)
    assert_equal 1, @sent.size
    assert_equal ["Quel est son mail ?", "Et son anniversaire ?"], client.requests.first[:messages].first(2).map { |m| m[:content] }
  end

  test "au-dela du plafond du jour, un seul avertissement et plus de modele" do
    last = nil
    SmsReplyJob::DAILY_LIMIT.times { last = @friend.messages.create!(direction: "inbound", status: "received", body: "encore") }
    client = FakeClient.new

    perform(client, last)
    assert_equal "limited", last.reload.status
    assert_equal SmsReplyJob::LIMIT_NOTICE, @sent.last[:body]
    assert_empty client.requests

    extra = @friend.messages.create!(direction: "inbound", status: "received", body: "encore")
    perform(client, extra)
    assert_equal 1, @sent.size
  end
end
