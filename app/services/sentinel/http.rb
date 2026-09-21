require "net/http"

# Petit client HTTP de Sentinelle (Net::HTTP, aucune gem) : suit les
# redirections, borne les délais et lève une erreur lisible. Un seul nouvel
# essai sur les erreurs passagères : la collecte d'une semaine enchaîne des
# centaines d'appels, un échec isolé ne doit pas faire tomber une source.
module Sentinel
  class Http
    class Error < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        super(message)
        @status = status
      end
    end

    USER_AGENT = "Mozilla/5.0 (compatible; Sentinelle/1.0; veille personnelle)".freeze
    MAX_REDIRECTS = 4
    RETRIABLE_STATUSES = [429, 502, 503, 504].freeze
    NETWORK_ERRORS = [
      Net::OpenTimeout, Net::ReadTimeout, SocketError, OpenSSL::SSL::SSLError,
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, EOFError
    ].freeze

    def self.get(url, headers: {}, params: nil, timeout: 30)
      uri = URI.parse(url)
      uri.query = [uri.query, URI.encode_www_form(params)].compact.join("&") if params.present?
      new(timeout: timeout).request(Net::HTTP::Get, uri, headers: headers)
    end

    def self.post_json(url, body, headers: {}, timeout: 30)
      new(timeout: timeout).request(Net::HTTP::Post, URI.parse(url), body: body.to_json,
                                    headers: { "Content-Type" => "application/json" }.merge(headers))
    end

    def self.post_form(url, form, timeout: 30)
      new(timeout: timeout).request(Net::HTTP::Post, URI.parse(url), body: URI.encode_www_form(form),
                                    headers: { "Content-Type" => "application/x-www-form-urlencoded" })
    end

    def initialize(timeout: 30)
      @timeout = timeout
    end

    # Renvoie le corps de la réponse (String).
    def request(verb, uri, headers: {}, body: nil, redirects: 0, retried: false)
      raise Error, "URL non http(s) : #{uri}" unless uri.is_a?(URI::HTTP)

      response = perform(verb, uri, headers, body)

      case response
      when Net::HTTPSuccess
        response.body.to_s
      when Net::HTTPRedirection
        raise Error, "Trop de redirections pour #{uri}" if redirects >= MAX_REDIRECTS

        # Une redirection se rejoue en GET, comme le fait un navigateur.
        request(Net::HTTP::Get, URI.join(uri.to_s, response["location"]), headers: headers, redirects: redirects + 1)
      else
        status = response.code.to_i
        return retry_request(verb, uri, headers, body, redirects) if RETRIABLE_STATUSES.include?(status) && !retried

        raise Error.new("HTTP #{status} sur #{uri.host}#{uri.path} : #{response.body.to_s.truncate(300)}",
                        status: status)
      end
    rescue *NETWORK_ERRORS => e
      return retry_request(verb, uri, headers, body, redirects) unless retried

      raise Error, "#{e.class} sur #{uri.host} : #{e.message}"
    end

    private

    def retry_request(verb, uri, headers, body, redirects)
      sleep 1 unless Rails.env.test?
      request(verb, uri, headers: headers, body: body, redirects: redirects, retried: true)
    end

    def perform(verb, uri, headers, body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = @timeout

      request = verb.new(uri.request_uri)
      request["User-Agent"] = USER_AGENT
      headers.each { |name, value| request[name] = value }
      request.body = body if body
      http.request(request)
    end
  end
end
