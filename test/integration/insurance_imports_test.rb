require "test_helper"

class InsuranceImportsTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json", "Accept" => "application/json" }.freeze
  ACCEPT_JSON = { "Accept" => "application/json" }.freeze

  class FakeExtractor
    def initialize(result = nil, error: nil)
      @result = result
      @error = error
    end

    def call(_blob)
      raise InsuranceImports::Error, @error if @error

      @result
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

  def done_import
    import = InsuranceImport.new
    import.file.attach(blob)
    import.save!
    draft = InsuranceImports::Extractor.normalize(InsuranceImports::ExtractorTest::FIELDS, properties: [])
    InsuranceImportJob.perform_now(import.id, extractor: FakeExtractor.new({ draft: draft, extractor: "pdf_reader" }))
    import.reload
  end

  test "le fichier envoye cree un import et enfile l'extraction" do
    assert_enqueued_with(job: InsuranceImportJob) do
      post api_insurance_imports_path, params: { file: blob.signed_id }.to_json, headers: JSON_HEADERS
    end
    assert_response :created
    json = response.parsed_body
    assert_equal "pending", json["status"]
    assert json["in_progress"]
  end

  test "un fichier qui n'est ni un PDF ni une image est refuse" do
    post api_insurance_imports_path, params: { file: blob(content_type: "text/plain", filename: "x.txt", content: "notes").signed_id }.to_json,
                                     headers: JSON_HEADERS
    assert_response :unprocessable_entity
  end

  test "sans cle Mistral, l'import est indisponible" do
    ENV["MISTRAL_API_KEY"] = nil
    post api_insurance_imports_path, params: { file: blob.signed_id }.to_json, headers: JSON_HEADERS
    assert_response :service_unavailable
  end

  test "le job range le brouillon, ou l'erreur" do
    import = done_import
    assert_equal "done", import.status
    assert_equal "MAIF", import.draft.dig("insurance", "insurer")

    failed = InsuranceImport.new
    failed.file.attach(blob)
    failed.save!
    InsuranceImportJob.perform_now(failed.id, extractor: FakeExtractor.new(error: "Aucun texte lisible dans le document"))
    get api_insurance_import_path(failed), headers: ACCEPT_JSON
    assert_equal "failed", response.parsed_body["status"]
    assert_equal "Aucun texte lisible dans le document", response.parsed_body["error"]
  end

  test "la confirmation cree le contrat, ses garanties, ses biens et le document du fichier" do
    import = done_import
    blob_id = import.file.blob.id

    post confirm_api_insurance_import_path(import), params: {
      insurance: { name: "Habitation Créteil", insurance_type: "habitation", insurer: "MAIF", premium: "254.80",
                   start_date: "2024-03-01" },
      coverages: [{ name: "Dégâts des eaux", included: true, deductible: "150 €" }, { name: "Vol", included: false }],
      items: [{ name: "Appartement", kind: "logement" }],
      document: { name: "Conditions particulières", category: "special_terms" }
    }.to_json, headers: JSON_HEADERS

    assert_response :created
    insurance = Insurance.find(response.parsed_body["id"])
    assert_equal ["Dégâts des eaux", "Vol"], insurance.insurance_coverages.map(&:name)
    assert_equal 1, insurance.insured_items.count
    document = insurance.documents.sole
    assert_equal ["insurance", "special_terms", Date.new(2024, 3, 1)], [document.domain, document.category, document.document_date]
    assert_equal blob_id, document.file.blob.id
    assert_not InsuranceImport.exists?(import.id)
    assert ActiveStorage::Blob.exists?(blob_id)
  end

  test "une fiche invalide ne cree rien et garde l'import" do
    import = done_import

    assert_no_difference ["Insurance.count", "Document.count"] do
      post confirm_api_insurance_import_path(import), params: { insurance: { name: "", insurance_type: "habitation" } }.to_json,
                                                      headers: JSON_HEADERS
    end
    assert_response :unprocessable_entity
    assert InsuranceImport.exists?(import.id)
  end

  test "abandonner supprime l'import ; les imports perimes sont purges" do
    import = done_import
    delete api_insurance_import_path(import), headers: ACCEPT_JSON
    assert_response :no_content
    assert_not InsuranceImport.exists?(import.id)

    stale = done_import
    stale.update_column(:created_at, 2.days.ago)
    InsuranceImport.purge_stale!
    assert_not InsuranceImport.exists?(stale.id)
  end
end
