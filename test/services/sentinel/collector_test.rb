require "test_helper"
require "minitest/mock"

class Sentinel::CollectorTest < ActiveSupport::TestCase
  # Faux adaptateur RSS : renvoie les documents prevus, ou leve l'erreur prevue.
  class FakeAdapter
    def initialize(result) = @result = result

    def each_document(**)
      raise @result if @result.is_a?(Exception)

      @result.each { |attributes| yield attributes }
    end
  end

  def attributes(id, title: "Article #{id}", content: "y" * 2000)
    { external_id: "example.org/#{id}", kind: "article", title: title, url: "https://example.org/#{id}",
      published_at: Time.zone.local(2026, 9, 16), raw_content: content, raw_metadata: {} }
  end

  def collect(week, adapters)
    Sentinel::Adapters::Rss.stub(:new, ->(source, **) { FakeAdapter.new(adapters.fetch(source.slug)) }) do
      Sentinel::Collector.new(week).call
    end
  end

  setup do
    @week = create(:sentinel_week, :pending)
  end

  test "stocke les nouveaux documents, les classe et ne garde pas le texte des hors champ" do
    create(:sentinel_source, :generalist, slug: "generaliste")
    warnings = collect(@week, "generaliste" => [
                         attributes(1, title: "Une théorie du complot démontée"),
                         attributes(2, title: "Résultats sportifs du week-end")
                       ])

    assert_empty warnings
    kept, dropped = @week.documents.order(:id).to_a
    assert kept.relevant
    assert_equal "desinformation", kept.domain
    assert_equal @week.monday, kept.monday
    assert kept.raw_content.present?
    assert_not dropped.relevant
    assert_nil dropped.raw_content
  end

  test "une seconde collecte ne duplique rien et conserve les resumes existants" do
    source = create(:sentinel_source, slug: "specialisee")
    create(:sentinel_document, :summarized, sentinel_source: source, external_id: "example.org/1", tldr: "Déjà résumé.")

    collect(@week, "specialisee" => [attributes(1), attributes(2)])

    assert_equal 2, @week.documents.count
    assert_equal "Déjà résumé.", SentinelDocument.find_by!(external_id: "example.org/1").tldr
    assert_equal 1, source.reload.last_documents_count, "seul le nouveau document est compte"
  end

  test "une source en panne devient un avertissement sans bloquer les autres" do
    broken = create(:sentinel_source, slug: "en_panne", name: "En panne")
    create(:sentinel_source, slug: "saine")

    warnings = collect(@week, "en_panne" => Sentinel::Http::Error.new("HTTP 503"), "saine" => [attributes(1)])

    assert_equal ["En panne - flux RSS : HTTP 503"], warnings
    assert_equal "flux RSS : HTTP 503", broken.reload.last_error
    assert_equal 1, @week.documents.count
  end

  test "deux domaines ne se melangent pas : seules les sources du domaine de la semaine sont collectees" do
    create(:sentinel_source, slug: "desinfo")
    create(:sentinel_source, slug: "juridique", domain: "droit_travail")

    collect(@week, "desinfo" => [attributes(1)])

    assert_equal %w[desinformation], SentinelDocument.distinct.pluck(:domain)
  end

  test "sans cle Tavily, la recherche web est ignoree avec un avertissement" do
    create(:sentinel_source, :web_only, slug: "web")

    warnings = Sentinel::TavilySearch.stub(:configured?, false) { Sentinel::Collector.new(@week).call }

    assert_equal 1, warnings.size
    assert_match(/Recherche web ignorée/, warnings.first)
  end
end
