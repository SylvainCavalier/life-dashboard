require "test_helper"

class AlfredToolsTest < ActiveSupport::TestCase
  setup do
    @conversation = AlfredConversation.create!
    @message = @conversation.messages.create!(role: "assistant", status: "processing", content: "")
    @context = Alfred::Tools::Context.new(conversation: @conversation, message: @message, seen: Set.new)
  end

  def run_tool(name, input)
    Alfred::Tools.run(name, input, @context)
  end

  test "describe_models donne la section de l'interface et les categories" do
    result, error = run_tool("describe_models", { "models" => %w[CvFormation Note] })

    assert_not error
    formation, note = result[:models]
    assert_match "Formations & travaux", formation[:note]
    assert_includes formation[:columns].find { |c| c[:name] == "category" }[:values], "seminaire"
    assert_not note.key?(:note)
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

  def document!(text, name: "Analyses")
    Document.create!(name: name, domain: "health", category: "analysis",
                     file: { io: StringIO.new(text), filename: "analyses.txt", content_type: "text/plain" })
  end

  test "read_document rend le texte integral, par tranches" do
    text = "Hemoglobine 15,6 g/dL. " * 1500
    document = document!(text)

    first, error = run_tool("read_document", { "id" => document.id })
    assert_not error
    assert_equal text.strip.length, first[:total_chars]
    assert_equal Alfred::Tools::ReadDocument::PAGE_CHARS, first[:text].length
    assert_equal "/api/documents/#{document.id}/download", first[:download]

    rest, = run_tool("read_document", { "id" => document.id, "offset" => first[:next_offset] })
    assert_nil rest[:next_offset]
    assert_equal text.strip, first[:text] + rest[:text]
  end

  test "read_document recolle le texte indexe sans en-tetes ni recouvrements" do
    document = document!("x")
    text = (1..900).map { |i| "Ligne #{i} du compte rendu." }.join("\n")
    chunks = Alfred::Corpus::Chunker.new.call(text)
    chunks.each_with_index do |chunk, position|
      AlfredChunk.create!(source: document, kind: "file", position: position, label: document.name,
                          content: "Document : Analyses (16/04/2025)\n#{chunk}", embedding: Array.new(Embeddings::DIMENSIONS, 0.1))
    end

    result, = run_tool("read_document", { "id" => document.id, "offset" => 0 })

    assert_operator chunks.size, :>, 1
    assert_equal "index", result[:origin]
    assert_equal text, Alfred::Corpus::Indexer.file_text(document)
  end

  test "seuls les enregistrements cites ET renvoyes par les outils deviennent des sources" do
    document = document!("Hemoglobine 15,6")
    other = document!("Autre", name: "Bail")
    run_tool("read_document", { "id" => document.id })

    reply = "Tout est normal [[Document##{document.id}]]. Voir aussi [[Document##{other.id}]]."
    text, sources = Alfred::Citations.extract(reply, seen: @context.seen)

    assert_equal "Tout est normal. Voir aussi.", text
    assert_equal [document.id], sources.map { |source| source["id"] }
    assert_equal "/api/documents/#{document.id}/download", sources.first["download"]
  end

  test "propose_memory propose, la confirmation retient et le prompt l'affiche" do
    contact = Contact.create!(first_name: "Paul", last_name: "Reboh")

    assert_no_difference "AlfredMemory.count" do
      result, error = run_tool("propose_memory", {
        "operation" => "create", "category" => "people", "subject_type" => "Contact", "subject_id" => contact.id,
        "content" => "Paul Reboh est un des meilleurs amis de Sylvain ; « Paul » sans precision, c'est lui.",
        "summary" => "Retenir qui est Paul"
      })
      assert_not error
      assert result[:action_id]
    end

    action = @conversation.actions.last
    assert_equal "remember", action.operation
    assert_equal "Personnes", action.new_attributes["categorie"]
    assert_equal "Contact##{contact.id}", action.new_attributes["fiche"]

    assert_difference "AlfredMemory.count", 1 do
      Alfred::ActionExecutor.new(action).confirm!
    end
    memory = AlfredMemory.find(action.reload.record_id)
    assert_equal "executed", action.status
    assert_includes Alfred::Prompt.stable_text, "(memoire ##{memory.id}, personnes) Paul Reboh est un des meilleurs amis"
    assert_includes Alfred::Prompt.stable_text, "[fiche Contact##{contact.id}]"
  end

  test "propose_memory corrige et oublie, et refuse une memoire modifiee entre-temps" do
    memory = AlfredMemory.create!(content: "La fac, c'est Paris 12.", category: "context")

    run_tool("propose_memory", { "operation" => "update", "id" => memory.id, "content" => "La fac, c'est l'ICP.",
                                 "summary" => "Corriger la fac" })
    revise = @conversation.actions.last
    assert_equal({ "fait" => "La fac, c'est l'ICP." }, revise.new_attributes)
    assert_equal({ "fait" => "La fac, c'est Paris 12." }, revise.before_attributes)

    memory.update!(content: "La fac, c'est Assas.")
    Alfred::ActionExecutor.new(revise).confirm!
    assert_equal "failed", revise.reload.status
    assert_equal "La fac, c'est Assas.", memory.reload.content

    run_tool("propose_memory", { "operation" => "delete", "id" => memory.id, "summary" => "Oublier la fac" })
    assert_difference "AlfredMemory.count", -1 do
      Alfred::ActionExecutor.new(@conversation.actions.last).confirm!
    end
  end

  test "propose_memory refuse une memoire vide, une fiche inconnue ou un modele illisible" do
    result, = run_tool("propose_memory", { "operation" => "create", "content" => " ", "summary" => "x" })
    assert_match "Validation refusee", result[:error]

    result, = run_tool("propose_memory", { "operation" => "create", "content" => "x", "subject_type" => "Contact",
                                            "subject_id" => 999_999, "summary" => "x" })
    assert_match "aucune fiche", result[:error]

    result, = run_tool("propose_memory", { "operation" => "create", "content" => "x", "subject_type" => "PasswordEntry",
                                            "subject_id" => 1, "summary" => "x" })
    assert_match "Validation refusee", result[:error]
    assert_equal 0, @conversation.actions.count
  end
end
