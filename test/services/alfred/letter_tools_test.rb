require "test_helper"

class AlfredLetterToolsTest < ActiveSupport::TestCase
  setup do
    @conversation = AlfredConversation.create!
    @message = @conversation.messages.create!(role: "assistant", status: "processing", content: "")
    @context = Alfred::Tools::Context.new(conversation: @conversation, message: @message, seen: Set.new)
    PersonalProfile.create!(first_name: "Sylvain", last_name: "Cavalier", address_line1: "12 rue des Lilas",
                            postal_code: "94000", city: "Créteil")
  end

  def run_tool(name, input)
    Alfred::Tools.run(name, input, @context)
  end

  test "Alfred propose un courrier en texte brut ; a la confirmation, le profil complete l'expediteur" do
    result, error = run_tool("propose_write", {
      "operation" => "create", "model" => "Letter", "summary" => "Courrier de résiliation (expéditeur : Monsieur, profil)",
      "attributes" => { "recipient" => "Free\n75371 Paris Cedex 08", "subject" => "Résiliation",
                        "mention" => "Lettre recommandée avec accusé de réception",
                        "body_text" => "Madame, Monsieur,\n\nJe résilie mon abonnement.\n\nSalutations distinguées." }
    })
    assert_not error, result.inspect

    assert_difference("Letter.count", 1) { Alfred::ActionExecutor.new(@conversation.actions.last).confirm! }

    letter = Letter.last
    assert_equal "Sylvain Cavalier\n12 rue des Lilas\n94000 Créteil", letter.sender
    assert_equal "Créteil", letter.place
    assert_equal "Sylvain Cavalier", letter.signatory
    assert_equal Date.current, letter.letter_date
    assert_equal "doc", letter.body["type"]
    assert_equal "Madame, Monsieur,\n\nJe résilie mon abonnement.\n\nSalutations distinguées.", letter.body_text
  end

  test "query_records rend le texte du courrier en entier, sans le JSON de l'editeur" do
    letter = create(:letter, body_text: "Madame,\n\n#{'Un long paragraphe. ' * 300}")

    result, error = run_tool("query_records", { "model" => "Letter" })

    assert_not error
    record = result[:records].first
    assert_not record.key?("body")
    assert_equal letter.body_text, record["body_text"]
    assert_operator record["body_text"].length, :>, Alfred::Tools::QueryRecords::MAX_VALUE_CHARS
    assert_includes @context.seen, ["Letter", letter.id]
  end

  test "Alfred peut proposer une reecriture du contenu d'un brouillon" do
    letter = create(:letter, body_text: "Version initiale.")

    run_tool("propose_write", { "operation" => "update", "model" => "Letter", "id" => letter.id, "summary" => "Réécriture",
                                "attributes" => { "body_text" => "Version revue." } })
    Alfred::ActionExecutor.new(@conversation.actions.last).confirm!

    assert_equal "Version revue.", letter.reload.body_text
  end

  test "describe_models signale le champ calcule et le prompt a sa section Courriers" do
    result, = run_tool("describe_models", { "models" => ["Letter"] })

    assert_equal ["body_text"], result[:models].first[:computed]
    assert_includes Alfred::Prompt.stable_text, "## Courriers"
  end
end
