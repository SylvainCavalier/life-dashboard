require "test_helper"

class Sentinel::UrlNormalizerTest < ActiveSupport::TestCase
  test "le meme article donne le meme identifiant malgre schema, www, suivi, ancre et slash final" do
    expected = "example.com/a/b?id=3"
    [
      "https://www.Example.com/a/b/?utm_source=x&id=3#frag",
      "http://example.com/a/b?id=3&fbclid=abc",
      "https://example.com/a/b/?id=3"
    ].each { |url| assert_equal expected, Sentinel::UrlNormalizer.call(url) }
  end

  test "une URL illisible est renvoyee telle quelle" do
    assert_equal "pas une url", Sentinel::UrlNormalizer.call(" pas une url ")
  end
end
