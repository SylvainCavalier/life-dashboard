# Repond a un texto entrant (Alfred::Sms::Agent). Pas de relance automatique : une
# reponse tardive ou en double couterait plus qu'un texto d'excuse.
class SmsReplyJob < ApplicationJob
  queue_as :default

  # Laisse arriver la suite d'un message envoye en plusieurs textos.
  COALESCE_DELAY = 4.seconds
  # Plafond par correspondant et par jour : chaque reponse paie Claude et Twilio.
  DAILY_LIMIT = ENV.fetch("SMS_DAILY_LIMIT", "30").to_i

  LIMIT_NOTICE = "Je crains d'avoir atteint mon quota de textos pour aujourd'hui. Je reprendrai demain.".freeze
  APOLOGY = "Un contretemps m'empeche de vous repondre pour l'instant. Veuillez reessayer dans un moment.".freeze

  discard_on ActiveRecord::RecordNotFound

  def perform(message_id)
    message = SmsMessage.find(message_id)
    return unless SmsMessage.where(id: message.id, status: "received").update_all(status: "processing") == 1

    correspondent = message.correspondent
    return message.update!(status: "merged") if correspondent.messages.inbound.where("id > ?", message.id).exists?
    return apply_limit(message, correspondent) if over_limit?(correspondent)

    answer(message, correspondent)
  end

  private

  def over_limit?(correspondent)
    today_count(correspondent) > DAILY_LIMIT
  end

  def today_count(correspondent)
    correspondent.messages.inbound.where(created_at: Time.current.all_day).count
  end

  # Un seul avertissement par jour, sur le premier texto au-dela du plafond.
  def apply_limit(message, correspondent)
    message.update!(status: "limited")
    correspondent.send_text!(LIMIT_NOTICE) if today_count(correspondent) == DAILY_LIMIT + 1
  rescue TwilioSms::Error => e
    Rails.logger.error "[SmsReplyJob] avertissement non envoye : #{e.message}"
  end

  def answer(message, correspondent)
    correspondent.send_text!(Alfred::Sms::Agent.new(message).call)
    message.update!(status: "answered")
  rescue StandardError => e
    Rails.logger.error "[SmsReplyJob] texto ##{message.id} en echec : #{e.class}: #{e.message}"
    message.update!(status: "failed", error: "#{e.class.name.demodulize}: #{e.message}".truncate(500))
    apologize(correspondent) unless e.is_a?(TwilioSms::Error)
  end

  def apologize(correspondent)
    correspondent.send_text!(APOLOGY)
  rescue TwilioSms::Error => e
    Rails.logger.error "[SmsReplyJob] excuse non envoyee : #{e.message}"
  end
end
