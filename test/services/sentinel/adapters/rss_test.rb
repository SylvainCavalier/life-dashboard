require "test_helper"

class Sentinel::Adapters::RssTest < ActiveSupport::TestCase
  # Faux client HTTP : renvoie le corps prevu pour chaque URL.
  class FakeHttp
    def initialize(bodies) = @bodies = bodies
    def get(url, **) = @bodies.fetch(url)
  end

  MONDAY = Date.new(2026, 9, 14)

  RSS = <<~XML.freeze
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:content="http://purl.org/rss/1.0/modules/content/">
      <channel>
        <title>Flux de test</title>
        <item>
          <title>Dans la semaine</title>
          <link>https://www.example.org/dans-la-semaine/?utm_source=rss</link>
          <pubDate>Wed, 16 Sep 2026 08:00:00 +0200</pubDate>
          <dc:creator>Jeanne Martin</dc:creator>
          <description><![CDATA[<p>Un <strong>extrait</strong> court.</p>]]></description>
          <content:encoded><![CDATA[<p>Le texte <em>complet</em> de l'article.</p>]]></content:encoded>
        </item>
        <item>
          <title>Trop ancien</title>
          <link>https://www.example.org/ancien</link>
          <pubDate>Wed, 02 Sep 2026 08:00:00 +0200</pubDate>
        </item>
        <item>
          <title>Sans date</title>
          <link>https://www.example.org/sans-date</link>
        </item>
      </channel>
    </rss>
  XML

  ATOM = <<~XML.freeze
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <entry>
        <title>Entrée Atom</title>
        <link rel="alternate" href="https://example.org/atom-1"/>
        <published>2026-09-20T21:30:00Z</published>
        <author><name>Paul Durand</name></author>
        <summary type="html">&lt;p&gt;Résumé Atom&lt;/p&gt;</summary>
      </entry>
    </feed>
  XML

  def documents_for(xml)
    source = build(:sentinel_source, feed_url: "https://www.example.org/feed")
    adapter = Sentinel::Adapters::Rss.new(source, http: FakeHttp.new("https://www.example.org/feed" => xml))
    [].tap { |docs| adapter.each_document(monday: MONDAY, sunday: MONDAY + 6) { |doc| docs << doc } }
  end

  test "ne garde que les articles dates de la semaine, avec le texte le plus complet" do
    documents = documents_for(RSS)

    assert_equal ["Dans la semaine"], documents.pluck(:title)
    document = documents.first
    assert_equal "example.org/dans-la-semaine", document[:external_id]
    assert_equal "Jeanne Martin", document[:author]
    assert_equal "Le texte complet de l'article.", document[:raw_content]
    assert_equal "article", document[:kind]
  end

  test "lit un flux Atom, dimanche soir heure de Paris compris" do
    documents = documents_for(ATOM)

    assert_equal 1, documents.size
    assert_equal "https://example.org/atom-1", documents.first[:url]
    assert_equal "Paul Durand", documents.first[:author]
    assert_equal "Résumé Atom", documents.first[:raw_content]
  end
end
