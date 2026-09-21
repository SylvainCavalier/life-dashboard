require "test_helper"
require "minitest/mock"

class SentinelWeekJobTest < ActiveJob::TestCase
  FakeCollector = Struct.new(:warnings) do
    def call = warnings
  end

  # Faux service : renvoie le resultat prevu, ou leve l'erreur prevue.
  FakeService = Struct.new(:result) do
    def call
      raise result if result.is_a?(Exception)

      result
    end
  end

  SUMMARY = { tldr: "Résumé.", key_points: ["Point"], importance: "medium", categories: ["propagande"],
              summary_model: "gpt-test", summarized_at: Time.zone.local(2026, 9, 21) }.freeze
  DIGEST = { content: { "tldr" => "Synthèse.", "key_themes" => [], "top_documents" => [],
                        "impact_summary" => "Impact.", "documents_count" => 1 }, model: "gpt-test" }.freeze

  def run_job(week, collector_warnings: [], summary: SUMMARY, digest: DIGEST)
    Sentinel::Collector.stub(:new, ->(*) { FakeCollector.new(collector_warnings) }) do
      Sentinel::DocumentSummarizer.stub(:new, ->(*, **) { FakeService.new(summary) }) do
        Sentinel::DigestGenerator.stub(:new, ->(*, **) { FakeService.new(digest) }) do
          Sentinel::Llm.stub(:configured?, true) { SentinelWeekJob.perform_now(week.id) }
        end
      end
    end
    week.reload
  end

  setup do
    @week = create(:sentinel_week, :pending)
    @document = create(:sentinel_document)
  end

  test "resume les documents retenus puis redige la synthese" do
    create(:sentinel_document, :irrelevant, sentinel_source: @document.sentinel_source)

    week = run_job(@week, collector_warnings: ["Source X - flux RSS : HTTP 503"])

    assert week.done?
    assert_equal "Synthèse.", week.digest["tldr"]
    assert_equal "gpt-test", week.digest_model
    assert_equal ["Source X - flux RSS : HTTP 503"], week.warnings
    assert_equal "Résumé.", @document.reload.tldr
    assert_equal 1, SentinelDocument.summarized.count, "un document hors champ n'est jamais resume"
  end

  test "un document deja resume n'est pas repaye a la relance" do
    @document.update!(SUMMARY.merge(tldr: "Ancien résumé."))

    run_job(@week, summary: RuntimeError.new("ne doit pas etre appele"))

    assert @week.reload.done?
    assert_equal "Ancien résumé.", @document.reload.tldr
  end

  test "un resume en echec laisse la semaine aboutir, avec un avertissement" do
    create(:sentinel_document, :summarized, sentinel_source: @document.sentinel_source)

    week = run_job(@week, summary: RuntimeError.new("timeout"))

    assert week.done?
    assert_match(/1 document\(s\) n'ont pas pu être résumés/, week.warnings.join)
    assert_nil @document.reload.summarized_at
  end

  test "une semaine sans document pertinent aboutit sans synthese" do
    @document.destroy

    week = run_job(@week)

    assert week.done?
    assert_not week.digest?
    assert_match(/Aucun document pertinent/, week.warnings.join)
  end

  test "l'echec de la synthese marque la semaine en echec et conserve la synthese precedente" do
    @week.update!(digest: { "tldr" => "Ancienne synthèse." })

    week = run_job(@week, digest: RuntimeError.new("boom"))

    assert week.failed?
    assert_match(/boom/, week.error)
    assert_equal "Ancienne synthèse.", week.digest["tldr"]
  end

  test "sans cle OpenAI, l'echec est explicite" do
    Sentinel::Collector.stub(:new, ->(*) { FakeCollector.new([]) }) do
      Sentinel::Llm.stub(:configured?, false) { SentinelWeekJob.perform_now(@week.id) }
    end

    assert @week.reload.failed?
    assert_match(/OPENAI_API_KEY/, @week.error)
  end

  test "une semaine deja traitee n'est pas relancee" do
    @week.update!(status: "done")

    Sentinel::Collector.stub(:new, ->(*) { raise "ne doit pas etre appele" }) { SentinelWeekJob.perform_now(@week.id) }

    assert @week.reload.done?
  end
end
