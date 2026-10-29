require "test_helper"

class DailyReports::CollectorTest < ActiveSupport::TestCase
  MONDAY = Date.new(2026, 10, 12)

  # Boite Gmail factice : fils au format de Gmail::Parser.thread_summary.
  class FakeGmail
    attr_reader :queries

    def initialize(threads, error: nil)
      @threads = threads
      @error = error
      @queries = []
    end

    def search(query, max_results:)
      @queries << query
      raise Gmail::Client::Error, @error if @error

      @threads
    end

    def send_as_aliases = [{ email: "sylvain@prudo.fr" }]

    def thread(id)
      { messages: [{ body: "Corps complet du fil #{id}" }] }
    end
  end

  def thread(id, from:, date: "2026-10-12T08:00:00+02:00", unread: true)
    { thread_id: id, subject: "Objet #{id}", from: from, date: date, unread: unread, starred: false,
      message_count: 1, labels: ["Prudo"], snippet: "L&#39;extrait" }
  end

  def collect(weekend: false, gmail: FakeGmail.new([]))
    travel_to(MONDAY.in_time_zone.change(hour: 9)) do
      DailyReports::Collector.new(MONDAY, weekend: weekend, gmail: gmail).call
    end
  end

  test "anniversaires des proches seulement, avec ce qu'ils aiment" do
    alexia = Contact.create!(first_name: "Alexia", relationship_type: "copine", birth_date: Date.new(1995, 10, 20), likes: "Le the vert")
    Contact.create!(first_name: "Lointain", relationship_type: "connaissance", birth_date: Date.new(1990, 10, 13))
    Contact.create!(first_name: "Tard", relationship_type: "ami", birth_date: Date.new(1990, 12, 1))

    birthdays = collect["sections"]["birthdays"]

    assert_equal ["Alexia"], birthdays.map { |b| b["name"] }
    assert_equal({ "ref" => "Contact##{alexia.id}", "in_days" => 8, "age" => 31, "likes" => "Le the vert" },
                 birthdays.first.slice("ref", "in_days", "age", "likes"))
  end

  test "renouvellements annuels et fins d'abonnement a 30 jours, pas les prelevements mensuels" do
    Subscription.create!(name: "Assurance", cost: 254, billing_cycle: "yearly", start_date: Date.new(2025, 11, 1))
    Subscription.create!(name: "Box", cost: 37, billing_cycle: "monthly", start_date: Date.new(2025, 1, 14))
    Subscription.create!(name: "Logiciel", cost: 40, billing_cycle: "monthly", start_date: Date.new(2025, 1, 3), end_date: Date.new(2026, 11, 3))

    subscriptions = collect["sections"]["subscriptions"].index_by { |s| s["name"] }

    assert_equal %w[Assurance Logiciel], subscriptions.keys.sort
    assert_equal 20, subscriptions["Assurance"]["renews_in_days"]
    assert_equal 22, subscriptions["Logiciel"]["ends_in_days"]
  end

  test "assurances actives dont l'echeance principale tombe sous deux mois" do
    soon = Insurance.create!(name: "Habitation", insurance_type: "habitation", renewal_date: Date.new(2024, 12, 1), premium: 20, premium_frequency: "monthly")
    Insurance.create!(name: "Auto", insurance_type: "auto", renewal_date: Date.new(2024, 3, 1))
    Insurance.create!(name: "Ancienne", insurance_type: "auto", renewal_date: Date.new(2024, 11, 1), status: "resiliee")

    insurances = collect["sections"]["insurances"]

    assert_equal ["Habitation"], insurances.map { |i| i["name"] }
    assert_equal({ "ref" => "Insurance##{soon.id}", "renews_in_days" => 50, "annual_premium" => "240,00 € / an" },
                 insurances.first.slice("ref", "renews_in_days", "annual_premium"))
  end

  test "garanties qui se terminent sous un mois" do
    soon = Warranty.create!(name: "Lave-linge", store: "Darty", purchased_on: MONDAY - 700, ends_on: MONDAY + 12)
    Warranty.create!(name: "Télévision", purchased_on: MONDAY - 100, ends_on: MONDAY + 45)
    Warranty.create!(name: "Ancien grille-pain", purchased_on: MONDAY - 800, ends_on: MONDAY - 1)

    warranties = collect["sections"]["warranties"]

    assert_equal ["Lave-linge"], warranties.map { |w| w["name"] }
    assert_equal({ "ref" => "Warranty##{soon.id}", "ends_in_days" => 12, "store" => "Darty" },
                 warranties.first.slice("ref", "ends_in_days", "store"))
  end

  test "CRM : rendez-vous proches et priorites hautes sans nouvelles ; absent le week-end" do
    soon = Contact.create!(first_name: "Rdv")
    soon.create_crm_profile!(next_appointment_on: MONDAY + 3)
    stale = Contact.create!(first_name: "Oublie")
    stale.create_crm_profile!(priority: "haute", last_contact_on: MONDAY - 60)
    recent = Contact.create!(first_name: "Recent")
    recent.create_crm_profile!(priority: "haute", last_contact_on: MONDAY - 5)

    assert_equal %w[Oublie Rdv], collect["sections"]["crm"].map { |c| c["name"] }.sort
    assert_not collect(weekend: true)["sections"].key?("crm")
    assert_not collect(weekend: true)["sections"].key?("projects")
  end

  test "projets : l'activite se lit dans le journal de bord" do
    travel_to(MONDAY - 120) { @prudo = create(:project, name: "Prudo", priority: 5) }
    paul = Contact.create!(first_name: "Paul", last_name: "Durand")
    create(:project_entry, project: @prudo, occurred_on: MONDAY - 2, title: "Pole de competitivite", contact: paul)
    create(:project_entry, project: @prudo, occurred_on: MONDAY - 90, title: "Ancienne entree")
    travel_to(MONDAY - 120) { @vide = create(:project, name: "Vide", priority: 4) }

    projects = collect["sections"]["projects"].index_by { |p| p["name"] }

    assert_equal 2, projects["Prudo"]["idle_days"]
    assert_equal false, projects["Prudo"]["journal_empty"]
    assert_equal [{ "date" => (MONDAY - 2).iso8601, "kind" => "Rendez-vous", "title" => "Pole de competitivite", "with" => "Paul Durand" }],
                 projects["Prudo"]["recent_entries"]
    assert projects["Vide"]["journal_empty"]
    assert_equal 120, projects["Vide"]["idle_days"]
  end

  test "CRM : les projets auxquels le contact est lie" do
    paul = Contact.create!(first_name: "Paul")
    paul.create_crm_profile!(next_appointment_on: MONDAY + 1)
    create(:project_contact, contact: paul, project: create(:project, name: "Prudo"))

    assert_equal ["Prudo"], collect["sections"]["crm"].first["projects"]
  end

  test "taches en retard, proches ou prioritaires, avec leur reference" do
    late = Task.create!(description: "En retard", priority: 2, deadline: MONDAY - 2)
    Task.create!(description: "Lointaine", priority: 2, deadline: MONDAY + 30)
    Task.create!(description: "Faite", priority: 5, completed: true)
    urgent = Task.create!(description: "Prioritaire", priority: 5)

    snapshot = collect
    tasks = snapshot["sections"]["tasks"]

    assert_equal ["En retard", "Prioritaire"], tasks.map { |t| t["description"] }
    assert_equal({ "label" => "En retard", "path" => "/" }, snapshot["refs"]["Task##{late.id}"])
    assert snapshot["refs"].key?("Task##{urgent.id}")
  end

  test "agenda de la semaine, sans les echeances, qui ont leur rubrique" do
    create(:event, title: "Avocat", start_time: MONDAY.in_time_zone.change(hour: 14), location: "Paris", end_time: nil)
    create(:event, title: "Plus tard", start_time: (MONDAY + 20).in_time_zone, end_time: nil)
    create(:event, title: "Taxe", event_type: "echeance", start_time: MONDAY.in_time_zone, end_time: nil)

    agenda = collect["sections"]["agenda"]

    assert_equal ["Avocat"], agenda.map { |e| e["title"] }
    assert_equal "14:00", agenda.first["start"]
    assert_equal 0, agenda.first["in_days"]
  end

  test "mails : ecarte ceux dont Sylvain a le dernier mot, lit les non-lus recents" do
    gmail = FakeGmail.new([
      thread("a1", from: "Agence <agence@immo.fr>"),
      thread("a2", from: "Sylvain <sylvain@prudo.fr>"),
      thread("a3", from: "Vieux <vieux@exemple.fr>", date: "2026-10-08T08:00:00+02:00")
    ])

    snapshot = collect(gmail: gmail)
    mails = snapshot["sections"]["mails"]

    assert_equal %w[Mail#a1 Mail#a3], mails.map { |m| m["ref"] }
    assert_equal "Corps complet du fil a1", mails.first["last_message"]
    assert_nil mails.last["last_message"]
    assert_equal "L'extrait", mails.first["snippet"]
    assert_equal 4, mails.last["age_days"]
    assert_match "#all/a1", snapshot["refs"]["Mail#a1"]["url"]
    assert_match "newer_than:5d", gmail.queries.first
    assert_match "is:unread newer_than:2d", FakeGmail.new([]).tap { |g| collect(weekend: true, gmail: g) }.queries.first
  end

  test "une panne Gmail devient un avertissement, pas un echec" do
    snapshot = collect(gmail: FakeGmail.new([], error: "quota depasse"))

    assert_empty snapshot["sections"]["mails"]
    assert_match "quota depasse", snapshot["warnings"].first
  end

  test "reprend les titres du rapport precedent" do
    create(:daily_report, :done, report_date: MONDAY - 1)

    assert_includes collect["previous"]["items"], "mails : Repondre a l'agence"
  end
end
