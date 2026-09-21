# Client des API hébergées sur PISTE (Judilibre, Légifrance) : OAuth2
# client_credentials, puis appels authentifiés par Bearer.
#
# Le jeton est relu à chaque requête (et non figé dans une connexion comme dans
# veille-juridique) : une collecte Légifrance dure plusieurs minutes, le jeton
# peut expirer en cours de route. Il est mémoïsé au niveau du processus, car
# Rails.cache est un null_store en développement : sans cela, chaque appel
# redemanderait un jeton.
module Sentinel
  module Piste
    class Client
      TOKEN_URL = "https://oauth.piste.gouv.fr/api/oauth/token".freeze
      API_BASE = "https://api.piste.gouv.fr".freeze
      JUDILIBRE_PATH = "/cassation/judilibre/v1.0".freeze
      LEGIFRANCE_PATH = "/dila/legifrance/lf-engine-app".freeze
      EXPIRY_GUARD = 60

      @token_mutex = Mutex.new

      class << self
        def configured?
          ENV["PISTE_CLIENT_ID"].present? && ENV["PISTE_CLIENT_SECRET"].present?
        end

        def token
          @token_mutex.synchronize do
            return @token if @token && @token_expires_at && @token_expires_at > Time.current

            fetch_token
          end
        end

        def reset_token!
          @token_mutex.synchronize { @token = @token_expires_at = nil }
        end

        private

        def fetch_token
          raise NotConfigured, "PISTE_CLIENT_ID / PISTE_CLIENT_SECRET absents de l'environnement" unless configured?

          body = Sentinel::Http.post_form(
            ENV.fetch("PISTE_TOKEN_URL", TOKEN_URL),
            { grant_type: "client_credentials", client_id: ENV.fetch("PISTE_CLIENT_ID"),
              client_secret: ENV.fetch("PISTE_CLIENT_SECRET"), scope: "openid" }
          )
          payload = JSON.parse(body)
          @token_expires_at = Time.current + [payload.fetch("expires_in", 3600).to_i - EXPIRY_GUARD, 60].max
          @token = payload.fetch("access_token")
        rescue Sentinel::Http::Error, JSON::ParserError, KeyError => e
          raise Error, "Authentification PISTE impossible : #{e.message}"
        end
      end

      def initialize(base_path)
        @base_url = ENV.fetch("PISTE_API_BASE", API_BASE) + base_path
      end

      def get(path, params: {})
        parse Sentinel::Http.get(@base_url + path, params: params, headers: headers)
      rescue Sentinel::Http::Error => e
        raise Error, "PISTE #{path} : #{e.message}"
      end

      def post(path, body)
        parse Sentinel::Http.post_json(@base_url + path, body, headers: headers)
      rescue Sentinel::Http::Error => e
        raise Error, "PISTE #{path} : #{e.message}"
      end

      private

      def headers
        { "Authorization" => "Bearer #{self.class.token}", "Accept" => "application/json" }
      end

      def parse(body)
        body.blank? ? {} : JSON.parse(body.dup.force_encoding(Encoding::UTF_8))
      rescue JSON::ParserError
        raise Error, "Reponse PISTE illisible : #{body.to_s.truncate(200)}"
      end
    end
  end
end
