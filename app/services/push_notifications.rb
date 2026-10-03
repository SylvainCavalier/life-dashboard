# Notifications Web Push vers les appareils abonnes (iPhone : webapp ajoutee a
# l'ecran d'accueil, iOS 16.4+ ; Mac : Safari ou Chrome). Pas de service tiers :
# le message est chiffre pour l'appareil et remis au service push du navigateur
# (Apple, Google, Mozilla), authentifie par une paire de cles VAPID.
#
# Variables : VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY (`bin/rails reminders:vapid_keys`
# les genere) et VAPID_SUBJECT (mailto: de contact ; a defaut GMAIL_USER). Apple
# refuse un sujet invalide (403 BadJwtToken) : c'est la premiere chose a verifier.
module PushNotifications
  NOT_CONFIGURED = "Notifications push non configurees (VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY).".freeze

  # Apple et Google gardent le message au plus ce temps si l'appareil est injoignable.
  TTL = 6.hours.to_i

  class << self
    # Remplacable en test : ->(subscription, message) { ... }
    attr_writer :transport

    def public_key
      ENV["VAPID_PUBLIC_KEY"].presence
    end

    def configured?
      public_key.present? && ENV["VAPID_PRIVATE_KEY"].present?
    end

    def subject
      ENV["VAPID_SUBJECT"].presence || (Gmail.user && "mailto:#{Gmail.user}")
    end

    # Envoie `payload` (Hash) a tous les appareils. Renvoie le nombre d'appareils atteints.
    def broadcast(payload)
      return 0 unless configured?

      message = payload.to_json
      PushSubscription.find_each.count { |subscription| deliver(subscription, message) }
    end

    def deliver(subscription, message)
      transport.call(subscription, message)
      subscription.update_columns(last_success_at: Time.current, last_error: nil)
      true
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription => e
      # 404 / 410 : l'abonnement n'existe plus cote navigateur, inutile d'insister.
      Rails.logger.info "[PushNotifications] abonnement ##{subscription.id} expire, supprime (#{e.class.name.demodulize})"
      subscription.destroy
      false
    rescue WebPush::Error, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
      error = e.respond_to?(:response) ? "#{e.class.name.demodulize} #{e.response.code} #{e.response.body.to_s.truncate(120)}" : e.message
      Rails.logger.error "[PushNotifications] echec vers l'abonnement ##{subscription.id} : #{error}"
      subscription.update_columns(last_failure_at: Time.current, last_error: error.truncate(250))
      false
    end

    private

    def transport
      @transport ||= lambda do |subscription, message|
        WebPush.payload_send(
          message: message,
          endpoint: subscription.endpoint, p256dh: subscription.p256dh, auth: subscription.auth,
          vapid: { subject: subject, public_key: public_key, private_key: ENV.fetch("VAPID_PRIVATE_KEY") },
          ttl: TTL, urgency: "high"
        )
      end
    end
  end
end
