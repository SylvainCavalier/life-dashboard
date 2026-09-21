require "test_helper"

class Sentinel::ArticleTextTest < ActiveSupport::TestCase
  PARAGRAPH = "Une phrase suffisamment longue pour compter comme un vrai paragraphe d'article de presse. ".freeze

  test "prefere le conteneur le plus dense a une vignette <article> de colonne laterale" do
    html = <<~HTML
      <html><head><meta property="article:published_time" content="2026-09-17T08:00:00+02:00"></head><body>
        <nav><p>#{PARAGRAPH * 10}</p></nav>
        <article class="vignette"><a href="/autre">Un autre article</a></article>
        <div class="post_content">#{(1..6).map { |i| "<p>#{i}. #{PARAGRAPH * 2}</p>" }.join}<p>Court.</p></div>
      </body></html>
    HTML

    text = Sentinel::ArticleText.extract(html)

    assert_operator text.length, :>, 900
    assert_includes text, "1. Une phrase"
    assert_not_includes text, "Un autre article"
    assert_not_includes text, "Court."
    assert_equal Time.utc(2026, 9, 17, 6), Sentinel::ArticleText.published_at(html)
  end

  test "rassemble des paragraphes repartis dans des blocs imbriques de <article>" do
    blocks = (1..5).map { |i| "<div class='bloc'><p>#{i}. #{PARAGRAPH * 2}</p></div>" }.join
    text = Sentinel::ArticleText.extract("<html><body><article>#{blocks}</article></body></html>")

    (1..5).each { |i| assert_includes text, "#{i}. Une phrase" }
  end

  test "lit la date dans le JSON-LD a defaut de balise meta, et renvoie nil sinon" do
    json_ld = '<script type="application/ld+json">{"@type":"NewsArticle","datePublished":"2026-09-15T10:00:00Z"}</script>'

    assert_equal Time.utc(2026, 9, 15, 10), Sentinel::ArticleText.published_at("<html><head>#{json_ld}</head></html>")
    assert_nil Sentinel::ArticleText.published_at("<html><body><p>Rien</p></body></html>")
  end

  test "une page illisible renvoie une page vide sans lever d'erreur" do
    failing = Class.new { def self.get(*, **) = raise(Sentinel::Http::Error, "HTTP 403") }

    page = Sentinel::ArticleText.read("https://example.org/x", http: failing)

    assert_nil page.text
    assert_nil page.published_at
  end
end
