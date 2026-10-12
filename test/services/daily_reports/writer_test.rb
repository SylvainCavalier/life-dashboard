require "test_helper"

class DailyReports::WriterTest < ActiveSupport::TestCase
  class FakeClient
    Block = Struct.new(:type, :text)
    Message = Struct.new(:content, :stop_reason, :model)

    attr_reader :params

    def initialize(json)
      @json = json
    end

    def messages = self

    def create(**params)
      @params = params
      Message.new([Block.new(:text, @json.to_json)], :end_turn, "claude-test")
    end
  end

  SNAPSHOT = {
    "date" => "2026-10-12", "weekend" => false, "warnings" => [],
    "sections" => { "tasks" => [{ "ref" => "Task#1", "description" => "Payer les charges" }] },
    "refs" => { "Task#1" => { "label" => "Payer les charges", "path" => "/" } }
  }.freeze

  def reply(items)
    { "headline" => "Journee calme.", "opening" => "Bonjour Monsieur.", "closing" => "A demain.",
      "today" => [], "mails" => [], "people" => [], "money" => [], "remarks" => [], "priorities" => items }
  end

  test "ecarte les references inventees et les elements sans titre" do
    client = FakeClient.new(reply([
      { "title" => "Charges", "detail" => "A payer.", "urgent" => true, "refs" => ["Task#1", "Task#99", "Mail#zzz"] },
      { "title" => " ", "detail" => "Vide.", "urgent" => false, "refs" => [] }
    ]))

    result = DailyReports::Writer.new(SNAPSHOT, client: client).call

    assert_equal [{ "title" => "Charges", "detail" => "A payer.", "urgent" => true, "refs" => ["Task#1"] }], result[:content]["priorities"]
    assert_equal "claude-test", result[:model]
  end

  test "envoie l'instantane sans la table des liens, avec le personnage et la consigne du rapport" do
    client = FakeClient.new(reply([]))
    DailyReports::Writer.new(SNAPSHOT, client: client).call

    prompt = client.params[:messages].first[:content]
    assert_match "Rapport du lundi 12 octobre 2026", prompt
    assert_match "\"Task#1\"", prompt
    assert_no_match "\"refs\"", prompt
    assert_match "Majordome britannique", client.params[:system]
    assert_match "## Rapport du matin", client.params[:system]
    assert_equal :json_schema, client.params.dig(:output_config, :format_, :type)
  end

  test "la consigne du rapport se surcharge depuis la page Alfred" do
    AlfredSetting.instance.update!(prompt_overrides: { "daily_report" => "Sois bref." })

    assert_match "Sois bref.", DailyReports::Writer.system_prompt
  end
end
