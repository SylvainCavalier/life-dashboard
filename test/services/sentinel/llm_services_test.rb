require "test_helper"

# Sentinel::DocumentSummarizer et Sentinel::DigestGenerator, avec un faux LLM
# qui capture le prompt et renvoie une reponse preparee.
class Sentinel::LlmServicesTest < ActiveSupport::TestCase
  class FakeLlm
    attr_reader :captured

    def initialize(content) = @content = content

    def call(**kwargs)
      @captured = kwargs
      { content: @content, model: "gpt-test" }
    end
  end

  test "le resume ne conserve que les categories du domaine et tronque le contenu" do
    domain = Sentinel::Domains.find!("desinformation")
    document = create(:sentinel_document, raw_content: "x" * 20_000)
    llm = FakeLlm.new("display_title" => nil, "tldr" => "Résumé.", "key_points" => %w[a b c],
                      "importance" => "high", "categories" => %w[propagande categorie-inventee])

    attributes = Sentinel::DocumentSummarizer.new(document, domain: domain, llm: llm).call

    assert_equal %w[propagande], attributes[:categories]
    assert_equal "high", attributes[:importance]
    assert_equal "gpt-test", attributes[:summary_model]
    assert_nil attributes[:display_title]
    assert_match(/contenu tronqué, 5000 caractères omis/, llm.captured[:input])
    assert_includes llm.captured[:instructions], "- propagande : Propagande et ingérences"
    assert_equal Sentinel::DocumentSummarySchema, llm.captured[:schema]
  end

  test "une importance hors echelle est ignoree" do
    domain = Sentinel::Domains.find!("desinformation")
    llm = FakeLlm.new("tldr" => "Résumé.", "key_points" => [], "importance" => "critique", "categories" => [])

    attributes = Sentinel::DocumentSummarizer.new(create(:sentinel_document), domain: domain, llm: llm).call

    assert_nil attributes[:importance]
  end

  test "la synthese ecarte les documents inventes par le modele et les doublons" do
    week = create(:sentinel_week, :pending)
    known = create(:sentinel_document, :summarized, importance: "high")
    other = create(:sentinel_document, :summarized, sentinel_source: known.sentinel_source)
    llm = FakeLlm.new(
      "tldr" => "Synthèse.", "key_themes" => ["Thème"], "impact_summary" => "Impact.",
      "top_documents" => [
        { "document_id" => known.id, "why" => "Notable." },
        { "document_id" => 999_999, "why" => "N'existe pas." },
        { "document_id" => known.id, "why" => "Doublon." }
      ]
    )

    result = Sentinel::DigestGenerator.new(week, [known, other], llm: llm).call

    assert_equal [{ "document_id" => known.id, "why" => "Notable." }], result[:content]["top_documents"]
    assert_equal 2, result[:content]["documents_count"]
    assert_equal "gpt-test", result[:model]
  end

  test "la synthese ne recoit que les resumes, jamais les textes bruts" do
    week = create(:sentinel_week, :pending)
    document = create(:sentinel_document, :summarized, raw_content: "TEXTE BRUT CONFIDENTIEL")
    llm = FakeLlm.new("tldr" => "S.", "key_themes" => [], "impact_summary" => "I.", "top_documents" => [])

    Sentinel::DigestGenerator.new(week, [document], llm: llm).call

    assert_not_includes llm.captured[:input], "TEXTE BRUT CONFIDENTIEL"
    assert_includes llm.captured[:input], "[document_id: #{document.id}]"
    assert_includes llm.captured[:input], document.tldr
    assert_includes llm.captured[:input], "Domaine de veille : Désinformation"
  end
end
