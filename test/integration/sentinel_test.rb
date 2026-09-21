require "test_helper"

class SentinelTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT = { "Accept" => "application/json" }.freeze

  setup { sign_in_owner }

  def json = JSON.parse(response.body)

  test "l'index des domaines liste les onglets et installe les sources par defaut" do
    get api_sentinel_domains_path, headers: ACCEPT
    assert_response :success

    assert_equal %w[droit_travail desinformation], json["domains"].pluck("key")
    assert_equal %w[openai piste tavily], json["configuration"].keys
    labor = json["domains"].first
    assert_equal 3, labor["sources_count"]
    assert labor["categories"].key?("rupture-licenciement")
    assert_nil labor["latest_week"]
  end

  test "la liste des semaines contient les semaines recentes meme vides, isolees par domaine" do
    week = create(:sentinel_week, monday: SentinelWeek.last_completed_monday)
    create(:sentinel_document, :summarized, monday: week.monday)

    get api_sentinel_domain_sentinel_weeks_path("desinformation"), headers: ACCEPT
    assert_response :success
    assert_operator json.size, :>=, 8
    populated = json.find { |w| w["monday"] == week.monday.to_s }
    assert_equal "done", populated["status"]
    assert_equal({ "total" => 1, "relevant" => 1, "summarized" => 1 }, populated["counts"])
    assert populated["has_digest"]

    get api_sentinel_domain_sentinel_weeks_path("droit_travail"), headers: ACCEPT
    other = json.find { |w| w["monday"] == week.monday.to_s }
    assert_nil other["status"], "la semaine d'un domaine n'apparait pas dans l'autre"
    assert_equal 0, other["counts"]["total"]
  end

  test "le detail d'une semaine renvoie la synthese et des documents sans leur texte" do
    week = create(:sentinel_week)
    low = create(:sentinel_document, :summarized, importance: "low")
    high = create(:sentinel_document, :summarized, importance: "high", sentinel_source: low.sentinel_source)

    get api_sentinel_domain_sentinel_week_path("desinformation", week.monday), headers: ACCEPT
    assert_response :success
    assert_equal week.digest["tldr"], json["digest"]["tldr"]
    assert_equal [high.id, low.id], json["documents"].pluck("id"), "tri par importance"
    assert_not json["documents"].first.key?("raw_content")
  end

  test "le detail d'une semaine jamais lancee repond sans erreur" do
    get api_sentinel_domain_sentinel_week_path("desinformation", "2026-09-07"), headers: ACCEPT
    assert_response :success
    assert_nil json["status"]
    assert_empty json["documents"]
  end

  test "lancer une veille enfile le job et repond 202" do
    assert_enqueued_with(job: SentinelWeekJob) do
      post run_api_sentinel_domain_sentinel_week_path("droit_travail", "2026-09-14"), headers: JSON_HEADERS
    end
    assert_response :accepted
    assert_equal "pending", json["status"]
  end

  test "une date qui n'est pas un lundi, une semaine future et un domaine inconnu sont refuses" do
    assert_no_enqueued_jobs do
      post run_api_sentinel_domain_sentinel_week_path("droit_travail", "2026-09-16"), headers: JSON_HEADERS
      assert_response :unprocessable_content

      future = (Date.current.beginning_of_week + 14).to_s
      post run_api_sentinel_domain_sentinel_week_path("droit_travail", future), headers: JSON_HEADERS
      assert_response :unprocessable_content

      post run_api_sentinel_domain_sentinel_week_path("cuisine", "2026-09-14"), headers: JSON_HEADERS
      assert_response :not_found
    end
  end

  test "supprimer une semaine supprime ses documents, pas ceux des autres semaines" do
    week = create(:sentinel_week)
    create(:sentinel_document)
    kept = create(:sentinel_document, monday: week.monday - 7)

    delete api_sentinel_domain_sentinel_week_path("desinformation", week.monday), headers: ACCEPT
    assert_response :no_content
    assert_equal [kept.id], SentinelDocument.pluck(:id)
    assert_not SentinelWeek.exists?(week.id)
  end

  test "le detail d'un document renvoie le texte et les points cles" do
    document = create(:sentinel_document, :summarized)

    get api_sentinel_document_path(document), headers: ACCEPT
    assert_response :success
    assert_equal document.raw_content, json["raw_content"]
    assert_equal document.key_points, json["key_points"]
  end

  test "creation, modification et suppression d'une source" do
    assert_difference "SentinelSource.count", 1 do
      post api_sentinel_domain_sentinel_sources_path("desinformation"),
           params: { sentinel_source: { name: "Hoaxbuster", url: "https://www.hoaxbuster.com", web_search: true,
                                        adapter: "judilibre" } }.to_json,
           headers: JSON_HEADERS
    end
    assert_response :created
    assert_equal "hoaxbuster", json["slug"]
    assert_nil json["adapter"], "l'adaptateur n'est pas un parametre accepte"
    assert_equal %w[web], json["channels"]

    source = SentinelSource.find(json["id"])
    patch api_sentinel_source_path(source), params: { sentinel_source: { active: false } }.to_json, headers: JSON_HEADERS
    assert_response :success
    assert_not source.reload.active

    delete api_sentinel_source_path(source), headers: ACCEPT
    assert_response :no_content
  end

  test "une source sans canal de collecte est refusee" do
    post api_sentinel_domain_sentinel_sources_path("desinformation"),
         params: { sentinel_source: { name: "Rien", web_search: false } }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_content
    assert json["errors"].any?
  end

  test "restaurer les sources par defaut complete sans dupliquer" do
    SentinelSource.seed_defaults!("droit_travail")
    SentinelSource.find_by!(slug: "village_justice").destroy

    post restore_defaults_api_sentinel_domain_sentinel_sources_path("droit_travail"), headers: JSON_HEADERS
    assert_response :success
    assert_equal 3, json.size
  end
end
