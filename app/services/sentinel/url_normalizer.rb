# Forme canonique d'une URL d'article, utilisée comme identifiant de
# dédoublonnage : le même article arrive par le flux RSS et par la recherche
# web avec des URL qui diffèrent par le schéma, le www, les paramètres de
# suivi ou le slash final (FakeNewsletter comparait les URL brutes).
module Sentinel
  module UrlNormalizer
    TRACKING = /\A(utm_|fbclid|gclid|xtor|at_|mc_|ref$|source$|origin$)/i

    def self.call(url)
      uri = URI.parse(url.to_s.strip)
      return url.to_s.strip if uri.host.blank?

      query = URI.decode_www_form(uri.query.to_s).reject { |name, _| name.match?(TRACKING) }
      path = uri.path.to_s.sub(%r{/+\z}, "")
      [uri.host.downcase.sub(/\Awww\./, ""), path, query.any? ? "?#{URI.encode_www_form(query)}" : ""].join
    rescue URI::InvalidURIError, ArgumentError
      url.to_s.strip
    end
  end
end
