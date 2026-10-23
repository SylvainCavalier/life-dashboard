require "test_helper"

class Gmail::ClientTest < ActiveSupport::TestCase
  # Capture la requete au lieu de l'envoyer ; la serialisation reproduit celle de
  # google-apis-core (ApiCommand#prepare!), c'est elle qui plantait.
  class FakeService
    attr_reader :bodies

    def initialize = @bodies = []

    def modify_thread(_user, _id, request)
      @bodies << JSON.parse(request.class::Representation.new(request).to_json(user_options: { skip_undefined: true }))
    end
  end

  setup do
    @service = FakeService.new
    @client = Gmail::Client.allocate
    @client.instance_variable_set(:@service, @service)
  end

  test "archiver ne retire qu'INBOX, sans liste d'ajout nulle" do
    @client.modify_thread("t1", add: [], remove: ["INBOX"])

    assert_equal [{ "removeLabelIds" => ["INBOX"] }], @service.bodies
  end

  test "ajout et retrait de libelles dans la meme requete" do
    @client.modify_thread("t1", add: ["STARRED"], remove: ["UNREAD"])

    assert_equal [{ "addLabelIds" => ["STARRED"], "removeLabelIds" => ["UNREAD"] }], @service.bodies
  end
end
