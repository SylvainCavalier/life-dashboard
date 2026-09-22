require "test_helper"

class AlfredToolsTest < ActiveSupport::TestCase
  setup do
    @conversation = AlfredConversation.create!
    @message = @conversation.messages.create!(role: "assistant", status: "processing", content: "")
    @context = Alfred::Tools::Context.new(conversation: @conversation, message: @message)
  end

  def run_tool(name, input)
    Alfred::Tools.run(name, input, @context)
  end

  test "query_records refuse le coffre-fort" do
    PasswordEntry.create!(name: "Banque", login: "sylvain", password: "s3cr3t-tres-long")

    result, error = run_tool("query_records", { "model" => "PasswordEntry" })

    assert error
    assert_match "non accessible", result[:error]
    assert_no_match(/s3cr3t/, result.to_json)
  end

  test "query_records filtre, trie et compte" do
    Note.create!(title: "Alpha", content: "a", important: true)
    Note.create!(title: "Beta", content: "b", important: false)

    result, error = run_tool("query_records", { "model" => "Note", "where" => { "title" => { "ilike" => "al%" } } })
    assert_not error
    assert_equal ["Alpha"], result[:records].map { |r| r["title"] }

    count, = run_tool("query_records", { "model" => "Note", "count_only" => true })
    assert_equal 2, count[:count]
  end

  test "query_records rejette un champ inconnu plutot que de l'injecter en SQL" do
    result, error = run_tool("query_records", { "model" => "Note", "where" => { "1=1; DROP TABLE notes" => 1 } })

    assert error
    assert_match "inconnu ou interdit", result[:error]
  end

  test "propose_write n'ecrit rien : il enregistre une proposition" do
    assert_no_difference "Note.count" do
      result, error = run_tool("propose_write", { "operation" => "create", "model" => "Note", "summary" => "Nouvelle note",
                                                  "attributes" => { "title" => "Courses", "content" => "Pain" } })
      assert_not error
      assert result[:action_id]
    end

    action = @conversation.actions.last
    assert action.proposed?
    assert_equal @message, action.message
  end

  test "propose_write refuse un champ hors liste blanche et un modele interdit" do
    result, error = run_tool("propose_write", { "operation" => "create", "model" => "Note", "summary" => "x",
                                                "attributes" => { "title" => "x", "created_at" => "2020-01-01" } })
    assert error
    assert_match "created_at", result[:error]

    _, error = run_tool("propose_write", { "operation" => "create", "model" => "PasswordEntry", "summary" => "x",
                                           "attributes" => { "name" => "x" } })
    assert error
  end

  test "la confirmation execute l'ecriture et laisse une note systeme" do
    run_tool("propose_write", { "operation" => "create", "model" => "Note", "summary" => "Nouvelle note",
                                "attributes" => { "title" => "Courses", "content" => "Pain" } })
    action = @conversation.actions.last

    assert_difference "Note.count", 1 do
      Alfred::ActionExecutor.new(action).confirm!
    end

    assert_equal "executed", action.reload.status
    assert_equal "Courses", Note.find(action.record_id).title
    assert_equal "event", @conversation.messages.last.role
    assert_raises(ArgumentError) { Alfred::ActionExecutor.new(action).confirm! }
  end

  test "l'annulation n'ecrit rien" do
    run_tool("propose_write", { "operation" => "create", "model" => "Note", "summary" => "x",
                                "attributes" => { "title" => "Courses", "content" => "Pain" } })

    assert_no_difference "Note.count" do
      Alfred::ActionExecutor.new(@conversation.actions.last).cancel!
    end
    assert_equal "cancelled", @conversation.actions.last.status
  end

  test "une modification perimee n'est pas appliquee" do
    note = Note.create!(title: "Avant", content: "x")
    run_tool("propose_write", { "operation" => "update", "model" => "Note", "id" => note.id, "summary" => "Renommer",
                                "attributes" => { "title" => "Apres" } })
    note.update!(title: "Entre-temps")

    action = Alfred::ActionExecutor.new(@conversation.actions.last).confirm!

    assert_equal "failed", action.status
    assert_equal "Entre-temps", note.reload.title
  end

  test "le contenu des messages est chiffre en base" do
    @message.update!(content: "IBAN FR7612345678901234567890123")

    raw = AlfredMessage.connection.select_value("SELECT content FROM alfred_messages WHERE id = #{@message.id}")

    assert_no_match(/FR76/, raw)
    assert_equal "IBAN FR7612345678901234567890123", @message.reload.content
  end
end
