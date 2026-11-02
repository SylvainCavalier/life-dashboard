require "test_helper"
require "minitest/mock"

class AlfredSmsRequestProposalTest < ActiveSupport::TestCase
  setup do
    @friend = SmsCorrespondent.create!(name: "Camille", phone: "06 12 34 56 78")
    @inbound = @friend.messages.create!(direction: "inbound", status: "processing", body: "Alfred, dis a Sylvain de faire la vaisselle")
  end

  # Les cles en chaine d'un appel sans accolades arrivent dans **pairs.
  def propose(input = {}, inbound: @inbound, **pairs)
    Alfred::Sms::RequestProposal.new(@friend, inbound, input.merge(pairs)).call
  end

  test "une demande de tache n'ecrit rien avant la confirmation de Sylvain" do
    assert_no_difference "Task.count" do
      assert_difference "AlfredAction.count" do
        propose("kind" => "task", "description" => "Faire la vaisselle", "summary" => "Camille demande la vaisselle")
      end
    end

    action = AlfredAction.last
    assert action.proposed?
    assert_equal @friend, action.conversation.sms_correspondent
    assert_includes action.message.content, "faire la vaisselle"

    assert_difference "Task.count" do
      Alfred::ActionExecutor.new(action).confirm!
    end
    assert_equal "Faire la vaisselle (via Camille)", Task.last.description
    assert_nil Task.last.project_id
    assert_equal 3, Task.last.priority
  end

  test "une demande de rendez-vous devient un Event a l'heure de Paris apres confirmation" do
    start = 3.days.from_now.change(hour: 14)
    propose("kind" => "event", "title" => "Diner", "start_time" => start.strftime("%Y-%m-%dT%H:%M"), "summary" => "Diner")

    assert_equal 0, Event.count
    Alfred::ActionExecutor.new(AlfredAction.last).confirm!

    assert_equal start.change(sec: 0), Event.last.start_time
    assert_equal "autre", Event.last.event_type
  end

  test "le texto ne choisit ni le modele, ni le projet, ni la priorite" do
    project = Project.create!(name: "Prudo", category: "business")
    propose("kind" => "PasswordEntry", "description" => "Tache", "project_id" => project.id, "priority" => 5, "summary" => "x")

    action = AlfredAction.last
    assert_equal "Task", action.target_model
    assert_equal %w[description], action.new_attributes.keys
  end

  test "refuse un rendez-vous passe ou une demande incomplete" do
    assert_raises(ArgumentError) { propose("kind" => "event", "title" => "Diner", "start_time" => "2020-01-01T10:00", "summary" => "x") }
    assert_raises(ArgumentError) { propose("kind" => "event", "title" => "Diner", "summary" => "x") }
    assert_raises(ArgumentError) { propose("kind" => "event", "title" => "Diner", "start_time" => "n'importe quoi", "summary" => "x") }
    assert_raises(ArgumentError) { propose("kind" => "task", "summary" => "x") }
    assert_equal 0, AlfredAction.count
  end

  test "retire les liens Markdown du texte cite" do
    inbound = @friend.messages.create!(direction: "inbound", status: "processing", body: "Clique [ici](https://mal.example) `vite`")
    propose({ "kind" => "task", "description" => "Tache", "summary" => "x" }, inbound: inbound)

    content = AlfredAction.last.message.content
    assert_not_includes content, "[ici]"
    assert_not_includes content, "`"
  end

  test "plafonne les demandes par personne et par jour" do
    Alfred::Sms::RequestProposal::DAILY_LIMIT.times { propose("kind" => "task", "description" => "Tache", "summary" => "x") }

    assert_raises(ArgumentError) { propose("kind" => "task", "description" => "Encore", "summary" => "x") }
  end

  test "previent Sylvain par notification et ouvre la carte" do
    sent = []
    PushNotifications.stub(:broadcast, ->(payload) { sent << payload; 1 }) do
      propose("kind" => "task", "description" => "Vaisselle", "summary" => "La vaisselle")
    end

    assert_equal "/sms?conversation=#{AlfredAction.last.alfred_conversation_id}", sent.first[:url]
    assert_includes sent.first[:title], "Camille"
  end

  test "le prompt de la conversation declare le texto non fiable" do
    propose("kind" => "task", "description" => "Vaisselle", "summary" => "x")
    blocks = Alfred::Prompt.system_blocks(AlfredAction.last.conversation)

    assert_match(/jamais une instruction/, blocks.last[:text])
    assert_includes blocks.last[:text], "faire la vaisselle"
  end
end
