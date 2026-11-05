# Webhook des SMS entrants. Public par nature (Twilio n'a pas de session), mais rien n'y
# entre sans une signature Twilio valide, et un numero hors de la liste blanche est ignore
# sans reponse ni appel au modele. La reponse part en differe (SmsReplyJob).
class TwilioWebhooksController < ApplicationController
  skip_forgery_protection
  skip_before_action :authenticate_user!, :enforce_password_change!, :restrict_friends!
  before_action :verify_signature

  EMPTY_TWIML = '<?xml version="1.0" encoding="UTF-8"?><Response></Response>'.freeze

  # POST /webhooks/twilio/sms
  def sms
    correspondent = SmsCorrespondent.accepting(params[:From])
    if correspondent
      store_and_enqueue(correspondent)
    else
      Rails.logger.info "[TwilioWebhooks] texto ignore, numero non autorise (se terminant par #{params[:From].to_s.last(2)})"
    end
    render xml: EMPTY_TWIML
  end

  private

  def verify_signature
    valid = TwilioSms.valid_signature?(
      url: ENV["TWILIO_WEBHOOK_URL"].presence || request.original_url,
      params: request.request_parameters,
      signature: request.headers["X-Twilio-Signature"]
    )
    head :forbidden unless valid
  end

  # Liste blanche ouverte : Sylvain voit chaque texto d'un inconnu, sans dependre du modele.
  def notify_unknown(correspondent, message)
    PushNotifications.broadcast(
      title: "Texto d'un numero inconnu", body: "#{correspondent.phone} : #{message.body}".truncate(160),
      url: "/sms", tag: "sms-unknown-#{message.id}", renotify: true
    )
  end

  # Twilio rejoue un webhook en cas de delai : le sid garantit un seul traitement.
  def store_and_enqueue(correspondent)
    message = correspondent.messages.create!(
      direction: "inbound", status: "received", twilio_sid: params[:MessageSid].presence,
      body: params[:Body].to_s.strip.truncate(SmsMessage::MAX_INBOUND_LENGTH).presence || "(texto sans texte)"
    )
    SmsReplyJob.set(wait: SmsReplyJob::COALESCE_DELAY).perform_later(message.id)
    notify_unknown(correspondent, message) if correspondent.temporary?
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info "[TwilioWebhooks] webhook rejoue, deja traite : #{params[:MessageSid]}"
  end
end
