require "test_helper"

class Projects::JournalTest < ActiveSupport::TestCase
  setup do
    @prudo = create(:project, name: "Prudo", category: "developpement")
    @paul = Contact.create!(first_name: "Paul", last_name: "Durand")
    ProjectContact.create!(project: @prudo, contact: @paul)
  end

  def past_event(**attributes)
    create(:event, { title: "Rendez-vous Prudo", event_type: "rdv", start_time: 3.hours.ago, end_time: 2.hours.ago,
                     location: "Paris" }.merge(attributes))
  end

  test "un rendez-vous cite par le nom du projet ou d'un de ses contacts y est rattache a la creation" do
    assert_equal @prudo, create(:event, title: "Démo de Prudo", start_time: 1.day.from_now, end_time: nil).project
    assert_equal @prudo, create(:event, title: "Déjeuner avec Paul Durand", start_time: 1.day.from_now, end_time: nil).project
    assert_nil create(:event, title: "Dentiste", start_time: 1.day.from_now, end_time: nil).project
    assert_nil create(:event, title: "Déjeuner avec Paul", start_time: 1.day.from_now, end_time: nil).project
  end

  test "un rendez-vous passe est consigne une fois, avec son interlocuteur" do
    event = past_event(title: "Point avec Paul Durand", project: @prudo)

    assert_equal 1, Projects::Journal.record_past_events!
    entry = @prudo.project_entries.sole
    assert_equal "agenda", entry.source
    assert_equal "Event##{event.id}", entry.source_ref
    assert_equal "rendez_vous", entry.kind
    assert_equal @paul, entry.contact
    assert_match "Paris (consigné depuis l'agenda)", entry.body
    assert event.reload.journaled_at

    # Supprimee a la main, l'entree ne revient pas.
    entry.destroy
    assert_equal 0, Projects::Journal.record_past_events!
  end

  test "un rendez-vous a venir, en cours, trop ancien ou sans projet n'est pas consigne" do
    create(:event, title: "Demain Prudo", project: @prudo, start_time: 1.day.from_now, end_time: nil)
    create(:event, title: "En cours Prudo", project: @prudo, start_time: 10.minutes.ago, end_time: 20.minutes.from_now)
    create(:event, title: "Vieux Prudo", project: @prudo, start_time: 20.days.ago, end_time: nil)
    past_event(title: "Sans projet")

    assert_equal 0, Projects::Journal.record_past_events!
  end

  test "pas de doublon d'une entree deja saisie pour le meme rendez-vous" do
    travel_to Time.zone.local(2026, 11, 12, 15, 0) do
      create(:project_entry, project: @prudo, occurred_on: Date.current, kind: "rendez_vous",
                             title: "Vu Paul pour Prudo", contact: @paul)
      event = past_event(title: "Café avec Paul Durand", project: @prudo)

      assert_equal 0, Projects::Journal.record_past_events!
      assert_equal 1, @prudo.project_entries.count
      assert event.reload.journaled_at
    end
  end

  test "une reunion consigne son compte rendu et reprend l'entree du rendez-vous du jour" do
    event = past_event(project: @prudo)
    Projects::Journal.record_event(event)
    meeting = create(:meeting, :transcribed, project: @prudo, held_at: event.start_time, status: "done",
                     summary: { "overview" => "On a parlé du lancement.", "decisions" => ["Lancer en janvier"],
                                "action_items" => [{ "description" => "Envoyer le devis" }] })

    Projects::Journal.record_meeting(meeting)

    entry = @prudo.project_entries.sole
    assert_equal "meeting", entry.source
    assert_equal "Meeting##{meeting.id}", entry.source_ref
    assert_equal "Réunion : Point sur le bail", entry.title
    assert_match "On a parlé du lancement.", entry.body
    assert_match "- Lancer en janvier", entry.body
    assert_match "- Envoyer le devis", entry.body
    assert meeting.reload.journaled_at
  end

  test "changer le projet d'une reunion deplace l'entree, le retirer la supprime" do
    other = create(:project, name: "Glucksbot")
    meeting = create(:meeting, :transcribed, project: @prudo, status: "done", summary: { "overview" => "Bilan." })
    Projects::Journal.record_meeting(meeting)

    meeting.update!(project: other)
    Projects::Journal.record_meeting(meeting)
    assert_equal 0, @prudo.project_entries.count
    assert_equal 1, other.project_entries.count

    meeting.update!(project: nil)
    Projects::Journal.record_meeting(meeting)
    assert_equal 0, ProjectEntry.count

    # Consignee une fois : remettre un projet ne recree rien.
    meeting.update!(project: @prudo)
    Projects::Journal.record_meeting(meeting)
    assert_equal 0, ProjectEntry.count
  end

  test "une session de code renvoyee avec la meme ref met l'entree a jour" do
    entry, created = Projects::Journal.record_code_session(project: @prudo, title: "Intégration Stripe",
                                                           occurred_on: Date.new(2026, 11, 12), body: "- [feat] Paiement",
                                                           ref: "2026-11-12 — Intégration Stripe")
    assert created
    assert_equal "code", entry.source
    assert_equal "travail", entry.kind

    again, created_again = Projects::Journal.record_code_session(project: @prudo, title: "Intégration Stripe",
                                                                 occurred_on: Date.new(2026, 11, 12),
                                                                 body: "- [feat] Paiement\n- [fix] Webhook",
                                                                 ref: "2026-11-12 — Intégration Stripe")
    assert_not created_again
    assert_equal entry.id, again.id
    assert_match "Webhook", again.reload.body
  end
end
