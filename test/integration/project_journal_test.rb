require "test_helper"

# Sessions de code envoyees par /historyupdate : jeton, pas de session.
class ProjectJournalTest < ActionDispatch::IntegrationTest
  TOKEN = "jeton-de-test-0123456789".freeze

  setup do
    @project = create(:project, name: "Prudo", category: "developpement")
    @previous = ENV["PROJECT_JOURNAL_TOKEN"]
    ENV["PROJECT_JOURNAL_TOKEN"] = TOKEN
  end

  teardown { ENV["PROJECT_JOURNAL_TOKEN"] = @previous }

  def send_session(payload, token: TOKEN)
    post "/api/project_journal", params: payload.to_json,
                                 headers: { "Content-Type" => "application/json", "Accept" => "application/json",
                                            "Authorization" => "Bearer #{token}" }
  end

  test "le slug par defaut d'un depot connu est son nom de dossier" do
    assert_equal "prudo", @project.slug
    assert_equal "conspi", create(:project, name: "Conspi.fr").slug
    assert_equal "jeu-video-3d-solo", create(:project).slug
  end

  test "sans jeton valide, rien n'est ecrit" do
    assert_no_difference "ProjectEntry.count" do
      send_session({ project: "prudo", title: "Intrus" }, token: "mauvais")
    end
    assert_response :unauthorized

    post "/api/project_journal", params: { project: "prudo", title: "Intrus" }.to_json,
                                 headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    assert_response :unauthorized
  end

  test "sans PROJECT_JOURNAL_TOKEN sur le serveur, l'API est fermee" do
    ENV["PROJECT_JOURNAL_TOKEN"] = nil
    send_session({ project: "prudo", title: "X" })
    assert_response :service_unavailable
  end

  test "une session est consignee puis mise a jour par la meme ref" do
    send_session({ project: "prudo", title: "Intégration Stripe", body: "- [feat] Paiement",
                   occurred_on: "2026-11-12", ref: "2026-11-12 — Intégration Stripe" })
    assert_response :created
    assert response.parsed_body["created"]
    entry = @project.project_entries.sole
    assert_equal "code", entry.source
    assert_equal Date.new(2026, 11, 12), entry.occurred_on

    send_session({ project: "PRUDO", title: "Intégration Stripe", body: "- [feat] Paiement\n- [fix] Webhook",
                   occurred_on: "2026-11-12", ref: "2026-11-12 — Intégration Stripe" })
    assert_response :ok
    assert_equal 1, @project.project_entries.count
    assert_match "Webhook", entry.reload.body
  end

  test "un projet inconnu renvoie la liste des slugs" do
    send_session({ project: "inconnu", title: "X" })
    assert_response :not_found
    assert_includes response.parsed_body["known"], "prudo"
  end

  test "une date invalide est refusee" do
    send_session({ project: "prudo", title: "X", occurred_on: "hier" })
    assert_response :unprocessable_entity
  end

  test "la liste des projets ne donne que slug, nom et statut" do
    get "/api/project_journal", headers: { "Accept" => "application/json", "Authorization" => "Bearer #{TOKEN}" }
    assert_response :ok
    assert_equal [{ "slug" => "prudo", "name" => "Prudo", "status" => "en_cours" }], response.parsed_body["projects"]
  end
end
