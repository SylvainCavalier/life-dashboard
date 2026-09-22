require "test_helper"
require "minitest/mock"

# Outils Gmail d'Alfred et execution des actions mail, sur un client factice :
# aucun appel reseau, et surtout aucune ecriture sans confirmation.
class AlfredMailToolsTest < ActiveSupport::TestCase
  class FakeGmail

    THREADS = {
      "t1" => { thread_id: "t1", subject: "Devis site", from: "alice@example.com", date: "2026-09-22T10:00:00+02:00",
                unread: true, in_inbox: true, starred: false, labels: [], snippet: "Bonjour, voici", message_count: 1 },
      "t2" => { thread_id: "t2", subject: "Newsletter", from: "news@example.com", date: "2026-09-21T10:00:00+02:00",
                unread: false, in_inbox: true, starred: false, labels: [], snippet: "Promo", message_count: 1 }
    }.freeze

    def initialize
      @sent = []
      @drafts = []
      @modifications = []
      @trashed = []
      @labels = [{ id: "INBOX", name: "INBOX", type: "system" }, { id: "Label_1", name: "Clients", type: "user" }]
    end

    def search(query, max_results: 20)
      query.include?("newsletter") ? [THREADS["t2"]] : THREADS.values.first(max_results)
    end

    def threads_summary(ids)
      ids.filter_map { |id| THREADS[id] }
    end

    def thread(id)
      raise Gmail::Client::NotFound, "Gmail : fil ou message introuvable" unless THREADS[id]

      { thread_id: id, subject: THREADS[id][:subject],
        messages: [{ message_id: "m-#{id}", from: THREADS[id][:from], body: "Corps du mail #{id}", attachments: [] }] }
    end

    def reply_headers(id)
      { in_reply_to: "<#{id}@x>", references: "<#{id}@x>" }
    end

    def send_as_aliases
      [{ email: "admin@sbclabs.fr", name: nil, default: true },
       { email: "sylvain@prudo.fr", name: "Sylvain Bertrand-Cavalier", default: false }]
    end

    attr_reader :sent, :drafts, :modifications, :trashed, :labels

    def find_or_create_label(name)
      (@labels.find do |l|
        l[:name] == name
      end || (@labels << { id: "Label_#{name}", name: name, type: "user" }).last)[:id]
    end

    def modify_thread(id, add: [], remove: [])
      @modifications << [id, add, remove]
      nil
    end

    def trash_thread(id)
      @trashed << id
      nil
    end

    def send_message(mail, thread_id: nil)
      @sent << [mail, thread_id]
      { message_id: "sent-1", thread_id: thread_id || "new" }
    end

    def create_draft(mail, thread_id: nil)
      @drafts << [mail, thread_id]
      { draft_id: "d1" }
    end
  end

  setup do
    @conversation = AlfredConversation.create!
    @message = @conversation.messages.create!(role: "assistant", status: "processing", content: "")
    @context = Alfred::Tools::Context.new(conversation: @conversation, message: @message)
    @gmail = FakeGmail.new
  end

  def with_gmail(&block)
    Gmail.stub(:enabled?, true) do
      Gmail.stub(:user, "admin@sbclabs.fr") do
        Gmail.stub(:client, @gmail, &block)
      end
    end
  end

  def run_tool(name, input)
    Alfred::Tools.run(name, input, @context)
  end

  test "sans configuration Gmail, les outils repondent une erreur explicite" do
    result, error = run_tool("search_mails", {})

    assert error
    assert_match "pas configure", result[:error]
  end

  test "search_mails et read_mail_thread lisent la boite" do
    with_gmail do
      result, error = run_tool("search_mails", { "query" => "newsletter" })
      assert_not error
      assert_equal(["Newsletter"], result[:threads].pluck(:subject))

      inbox, = run_tool("search_mails", {})
      assert_equal "in:inbox", inbox[:query]
      assert_equal 2, inbox[:count]

      thread, error = run_tool("read_mail_thread", { "thread_id" => "t1" })
      assert_not error
      assert_equal "Corps du mail t1", thread[:messages].first[:body]

      missing, error = run_tool("read_mail_thread", { "thread_id" => "nope" })
      assert error
      assert_match "introuvable", missing[:error]
    end
  end

  test "propose_email n'envoie rien : la confirmation envoie, dans le fil, avec les en-tetes de reponse" do
    with_gmail do
      result, error = run_tool("propose_email", { "mode" => "send", "to" => ["alice@example.com"], "subject" => "Re: Devis site",
                                                  "body" => "Bonjour Alice,\n\nC'est bon pour moi.\n\nSylvain",
                                                  "reply_to_thread_id" => "t1", "summary" => "Reponse a Alice" })
      assert_not error
      assert result[:action_id]
      assert_empty @gmail.sent

      action = @conversation.actions.last
      assert_equal "send_email", action.operation
      assert_equal "Gmail", action.target_model
      assert_equal ["alice@example.com"], action.new_attributes["to"]
      assert_equal "t1", action.data["headers"]["thread_id"]

      Alfred::ActionExecutor.new(action).confirm!

      assert_equal "executed", action.reload.status
      mail, thread_id = @gmail.sent.first
      assert_equal "t1", thread_id
      assert_equal ["admin@sbclabs.fr"], mail.from
      assert_equal "t1@x", mail.in_reply_to
      assert_match "envoye", @conversation.messages.where(role: "event").last.content
    end
  end

  test "propose_email en mode draft cree un brouillon a la confirmation, et refuse une adresse invalide" do
    with_gmail do
      run_tool("propose_email", { "mode" => "draft", "to" => ["bob@example.com"], "subject" => "Hello",
                                  "body" => "Test", "summary" => "Brouillon" })
      Alfred::ActionExecutor.new(@conversation.actions.last).confirm!
      assert_equal 1, @gmail.drafts.size
      assert_empty @gmail.sent

      result, error = run_tool("propose_email", { "mode" => "send", "to" => ["pas une adresse"], "subject" => "x",
                                                  "body" => "y", "summary" => "z" })
      assert error
      assert_match "Adresse invalide", result[:error]
    end
  end

  test "l'adresse d'envoi doit etre un alias verifie ; le nom d'affichage de l'alias est repris" do
    with_gmail do
      result, error = run_tool("propose_email", { "mode" => "send", "from" => "mail@sylvaincavalier.com",
                                                  "to" => ["bob@example.com"], "subject" => "x", "body" => "y", "summary" => "z" })
      assert error
      assert_match "sylvain@prudo.fr", result[:error]
      assert_equal 0, @conversation.actions.count

      run_tool("propose_email", { "mode" => "send", "from" => "Sylvain@prudo.fr", "to" => ["bob@example.com"],
                                  "subject" => "x", "body" => "y", "summary" => "z" })
      action = @conversation.actions.last
      assert_equal "sylvain@prudo.fr", action.new_attributes["from"]

      Alfred::ActionExecutor.new(action).confirm!
      mail, = @gmail.sent.first
      assert_equal ["sylvain@prudo.fr"], mail.from
      assert_equal "Sylvain Bertrand-Cavalier", mail[:from].display_names.first
    end
  end

  test "l'annulation d'un mail propose n'envoie rien" do
    with_gmail do
      run_tool("propose_email",
               { "mode" => "send", "to" => ["bob@example.com"], "subject" => "x", "body" => "y", "summary" => "z" })
      Alfred::ActionExecutor.new(@conversation.actions.last).cancel!

      assert_empty @gmail.sent
      assert_equal "cancelled", @conversation.actions.last.status
    end
  end

  test "propose_mail_triage ne touche a rien avant confirmation, puis applique le lot" do
    with_gmail do
      result, error = run_tool("propose_mail_triage", { "thread_ids" => %w[t1 t2], "actions" => %w[mark_read add_label archive],
                                                        "label" => "Clients", "summary" => "Classer et archiver" })
      assert_not error
      assert result[:action_id]
      assert_empty @gmail.modifications

      action = @conversation.actions.last
      assert_equal "triage_email", action.operation
      assert_equal ["Devis site (alice@example.com)", "Newsletter (news@example.com)"], action.new_attributes["fils"]
      assert_equal ["marquer lu", "ajouter le libelle", "archiver"], action.new_attributes["actions"]

      Alfred::ActionExecutor.new(action).confirm!

      assert_equal "executed", action.reload.status
      assert_equal [["t1", [], ["UNREAD"]], ["t2", [], ["UNREAD"]],
                    ["t1", ["Label_1"], []], ["t2", ["Label_1"], []],
                    ["t1", [], ["INBOX"]], ["t2", [], ["INBOX"]]], @gmail.modifications
    end
  end

  test "propose_mail_triage refuse un fil inconnu, une action inconnue ou un libelle manquant" do
    with_gmail do
      _, error = run_tool("propose_mail_triage",
                          { "thread_ids" => %w[t1 zz], "actions" => %w[archive], "summary" => "x" })
      assert error

      result, error = run_tool("propose_mail_triage",
                               { "thread_ids" => %w[t1], "actions" => %w[delete_forever], "summary" => "x" })
      assert error
      assert_match "inconnues", result[:error]

      result, error = run_tool("propose_mail_triage",
                               { "thread_ids" => %w[t1], "actions" => %w[add_label], "summary" => "x" })
      assert error
      assert_match "label", result[:error]
      assert_equal 0, @conversation.actions.count
    end
  end

  test "une panne Gmail a la confirmation met l'action en echec sans lever" do
    with_gmail do
      run_tool("propose_mail_triage", { "thread_ids" => %w[t1], "actions" => %w[trash], "summary" => "x" })
      action = @conversation.actions.last

      @gmail.stub(:trash_thread, ->(_) { raise Gmail::Client::Error, "Gmail : quota" }) do
        Alfred::ActionExecutor.new(action).confirm!
      end

      assert_equal "failed", action.reload.status
      assert_match "quota", action.error
    end
  end

  test "propose_write ne connait que create et update" do
    _, error = run_tool("propose_write", { "operation" => "send_email", "model" => "Note", "summary" => "x",
                                           "attributes" => { "title" => "x" } })
    assert error
  end
end
