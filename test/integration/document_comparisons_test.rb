require "test_helper"

class DocumentComparisonsTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  FIELDS = {
    "title_a" => "Contrat v1", "title_b" => "Contrat v2", "relationship" => "versions",
    "verdict" => "La version 2 allonge la période d'essai.", "summary" => "Deux versions du même contrat.",
    "similarities" => [], "differences" => [], "only_in_a" => [], "only_in_b" => [], "attention_points" => []
  }.freeze

  class FakeComparator
    def initialize(error: nil) = @error = error

    def call(_blob_a, _blob_b, focus: nil)
      raise DocumentComparisons::Error, @error if @error

      { result: DocumentComparisons::Comparator.normalize(FIELDS).merge(focus: focus),
        extractors: { a: "pdf_reader", b: "mistral_ocr" } }
    end
  end

  setup do
    sign_in_owner
    @previous_key = ENV["MISTRAL_API_KEY"]
    ENV["MISTRAL_API_KEY"] = "test"
  end

  teardown { ENV["MISTRAL_API_KEY"] = @previous_key }

  def blob(content_type: "application/pdf", filename: "contrat.pdf", content: "%PDF-1.4 contrat")
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename: filename, content_type: content_type)
  end

  def comparison(user: User.owner)
    record = DocumentComparison.new(user: user)
    record.file_a.attach(blob(filename: "v1.pdf"))
    record.file_b.attach(blob(filename: "v2.pdf"))
    record.save!
    record
  end

  test "les deux PDF creent une comparaison et enfilent le job" do
    assert_enqueued_with(job: DocumentComparisonJob) do
      post api_document_comparisons_path, params: { file_a: blob(filename: "v1.pdf").signed_id, file_b: blob(filename: "v2.pdf").signed_id,
                                                    focus: "Période d'essai" }.to_json, headers: JSON_HEADERS
    end
    assert_response :created
    json = response.parsed_body
    assert json["in_progress"]
    assert_equal %w[v1.pdf v2.pdf], json.values_at("name_a", "name_b")
    assert_equal "Période d'essai", json["focus"]
  end

  test "un fichier manquant ou qui n'est pas un PDF est refuse" do
    post api_document_comparisons_path, params: { file_a: blob.signed_id }.to_json, headers: JSON_HEADERS
    assert_response :unprocessable_entity

    post api_document_comparisons_path, params: { file_a: blob.signed_id, file_b: blob(content_type: "image/png", filename: "x.png", content: "\x89PNG\r\n\x1a\n").signed_id }.to_json,
                                        headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "sans cle Mistral, le comparateur est indisponible" do
    ENV["MISTRAL_API_KEY"] = nil
    post api_document_comparisons_path, params: { file_a: blob.signed_id, file_b: blob.signed_id }.to_json, headers: JSON_HEADERS
    assert_response :service_unavailable
  end

  test "le job range le resultat et purge les fichiers" do
    record = comparison
    DocumentComparisonJob.perform_now(record.id, comparator: FakeComparator.new)
    record.reload

    assert_equal "done", record.status
    assert_equal "versions", record.result["relationship"]
    assert_not record.file_a.attached?
    assert_not record.file_b.attached?

    get api_document_comparison_path(record), headers: ACCEPT_JSON
    assert_equal "La version 2 allonge la période d'essai.", response.parsed_body.dig("result", "verdict")
  end

  test "un echec est consigne et les fichiers sont purges aussi" do
    record = comparison
    DocumentComparisonJob.perform_now(record.id, comparator: FakeComparator.new(error: "Aucun texte lisible dans le second document"))
    record.reload

    assert_equal "failed", record.status
    assert_equal "Aucun texte lisible dans le second document", record.error
    assert_not record.file_a.attached?
  end

  test "une comparaison bloquee s'affiche en echec" do
    record = comparison
    record.update_columns(status: "running", created_at: 1.hour.ago)
    get api_document_comparison_path(record), headers: ACCEPT_JSON
    assert_equal "failed", response.parsed_body["status"]
    assert_not response.parsed_body["in_progress"]
  end

  test "l'historique et la suppression ne portent que sur les comparaisons du compte" do
    mine = comparison
    friend = create(:user, :friend)
    theirs = comparison(user: friend)

    get api_document_comparisons_path, headers: ACCEPT_JSON
    assert_equal [mine.id], response.parsed_body["comparisons"].pluck("id")

    delete api_document_comparison_path(theirs), headers: ACCEPT_JSON
    assert_response :not_found

    delete api_document_comparison_path(mine), headers: ACCEPT_JSON
    assert_response :no_content
    assert_not DocumentComparison.exists?(mine.id)
  end
end
