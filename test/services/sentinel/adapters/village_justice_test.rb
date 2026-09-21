require "test_helper"

class Sentinel::Adapters::VillageJusticeTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :requested

    def initialize(bodies)
      @bodies = bodies
      @requested = []
    end

    def get(url, **)
      @requested << url
      @bodies.fetch(url) { "<html><body></body></html>" }
    end
  end

  INDEX_URL = "https://www.village-justice.com/articles/droit-social".freeze
  MONDAY = Date.new(2026, 9, 14)

  # Gabarit des pages de rubrique : auteur colle au titre, date dans un <em>,
  # et un chapo qui cite une AUTRE date (piege).
  def entry(id, title, date)
    <<~HTML
      <div class="col-xs-12">
        <div class="col-xs-9">
          <article>
            <a href="slug-article,#{id}.html">
              <h4 class="txt-bleu-titre mt-1">#{title}</h4>
              <span class="txt-gris">Par un arrêt du 25 juin 2026, la Cour de cassation juge que (...)</span>
            </a>
          </article>
          <h5 class="txt-bleu"><em><span class="lnr"></span>&nbsp;#{date}</em></h5>
        </div>
      </div>
    HTML
  end

  def adapter_with(index_html, extra = {})
    source = build(:sentinel_source, :judilibre, adapter: "village_justice", slug: "village_justice", url: INDEX_URL)
    http = FakeHttp.new({ INDEX_URL => index_html }.merge(extra))
    [Sentinel::Adapters::VillageJustice.new(source, http: http), http]
  end

  def collect(adapter)
    [].tap { |docs| adapter.each_document(monday: MONDAY, sunday: MONDAY + 6) { |doc| docs << doc } }
  end

  test "extrait les articles de la semaine avec titre, auteur, date de publication et texte" do
    index = "<html><body>#{entry(59_022, 'Rupture conventionnelle et salarié protégé. Par Frédéric Chhum, Avocat.', '15 septembre 2026')}" \
            "#{entry(58_900, 'Article plus ancien. Par Jean Dupont, Avocat.', '2 septembre 2026')}</body></html>"
    article_url = "https://www.village-justice.com/articles/slug-article,59022.html"
    adapter, = adapter_with(index, article_url => '<div class="texte-article texte-reader"><p>Texte intégral de l\'article.</p></div>')

    documents = collect(adapter)

    assert_equal 1, documents.size
    document = documents.first
    assert_equal "59022", document[:external_id]
    assert_equal "Rupture conventionnelle et salarié protégé", document[:title]
    assert_equal "Frédéric Chhum, Avocat.", document[:author]
    assert_equal Date.new(2026, 9, 15), document[:published_at], "la date du chapo ne doit pas etre prise"
    assert_equal article_url, document[:url]
    assert_equal "Texte intégral de l'article.", document[:raw_content]
    assert_equal "doctrine", document[:kind]
  end

  test "avance dans la pagination tant que le lundi vise n'est pas depasse" do
    page_one = "<html><body>#{entry(1, 'Récent. Par A B, Avocat.', '18 septembre 2026')}</body></html>"
    page_two = "<html><body>#{entry(2, 'Plus ancien. Par C D, Avocat.', '10 septembre 2026')}</body></html>"
    adapter, http = adapter_with(page_one, "#{INDEX_URL}?debut_artsuiv=20" => page_two)

    collect(adapter)

    assert_includes http.requested, "#{INDEX_URL}?debut_artsuiv=20"
    assert_not_includes http.requested, "#{INDEX_URL}?debut_artsuiv=40"
  end

  test "une page dont on ne tire aucun article leve une erreur au lieu de renvoyer zero document" do
    adapter, = adapter_with("<html><body><h1>Nouveau site</h1></body></html>")

    error = assert_raises(Sentinel::Adapters::VillageJustice::LayoutChanged) { collect(adapter) }
    assert_match(/structure du site/, error.message)
  end
end
