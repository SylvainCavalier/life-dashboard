# Envoi de SMS et verification des webhooks Twilio, par Net::HTTP (l'API REST tient en
# un appel : la gem twilio-ruby et ses dependances alourdiraient le slug pour rien).
#
# Variables : TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER (E.164) et,
# facultative, TWILIO_WEBHOOK_URL (URL exacte declaree dans la console Twilio, si elle
# differe de celle que Rails reconstitue : la signature porte dessus).
module TwilioSms
  class Error < StandardError; end

  NOT_CONFIGURED = "SMS non configures (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER).".freeze
  API_HOST = "api.twilio.com".freeze
  TIMEOUT = 15

  class << self
    # Remplacable en test : ->(to:, body:) { "SM..." } renvoie le sid du message.
    attr_writer :transport

    def number = ENV["TWILIO_PHONE_NUMBER"].presence
    def account_sid = ENV["TWILIO_ACCOUNT_SID"].presence
    def auth_token = ENV["TWILIO_AUTH_TOKEN"].presence

    def configured?
      number.present? && account_sid.present? && auth_token.present?
    end

    # Renvoie le sid Twilio. « Accepte » ne veut pas dire « remis » : le suivi de
    # remise est dans les journaux de la console Twilio.
    def send_message(to:, body:)
      raise Error, NOT_CONFIGURED unless @transport || configured?

      transport.call(to: to, body: body)
    end

    # https://www.twilio.com/docs/usage/webhooks/webhooks-security : HMAC-SHA1 de l'URL
    # complete suivie des parametres POST tries par nom. Sans jeton, tout est refuse.
    def valid_signature?(url:, params:, signature:)
      return false if auth_token.blank? || signature.blank?

      data = url + params.sort.map { |key, value| "#{key}#{value}" }.join
      expected = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", auth_token, data))
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    private

    def transport
      @transport || method(:post_message)
    end

    def post_message(to:, body:)
      request = Net::HTTP::Post.new("/2010-04-01/Accounts/#{account_sid}/Messages.json")
      request.basic_auth(account_sid, auth_token)
      request.set_form_data("To" => to, "From" => number, "Body" => body)

      response = Net::HTTP.start(API_HOST, 443, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(request)
      end
      payload = JSON.parse(response.body.presence || "{}")
      raise Error, "Twilio #{payload['code'] || response.code} : #{payload['message'] || 'reponse inattendue'}" unless response.is_a?(Net::HTTPSuccess)

      payload.fetch("sid")
    rescue JSON::ParserError, KeyError
      raise Error, "Reponse illisible de Twilio (HTTP #{response&.code})"
    rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      raise Error, "Twilio injoignable : #{e.message}"
    end
  end
end
