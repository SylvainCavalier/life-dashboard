# Produit la reponse d'Alfred a un message (Alfred::Agent). Un echec est consigne
# sur le message (status "failed" + error) sans etre releve : la table fait foi.
class AlfredReplyJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(message_id)
    message = AlfredMessage.find(message_id)
    # Idempotence : une re-execution GoodJob ne relance pas une reponse.
    return unless message.status == "pending"

    message.update!(status: "processing")
    Alfred::Agent.new(message).call
    message.conversation.update!(last_message_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    Rails.logger.error "[AlfredReplyJob] message ##{message_id} en echec : #{e.class}: #{e.message}"
    AlfredMessage.where(id: message_id).update_all(status: "failed", error: friendly_error(e), updated_at: Time.current)
  end

  private

  def friendly_error(error)
    case error
    when Anthropic::Errors::AuthenticationError then "Cle ANTHROPIC_API_KEY refusee par l'API."
    when Anthropic::Errors::RateLimitError then "L'API est momentanement saturee, reessayez dans un instant."
    when Anthropic::Errors::APIConnectionError then "Connexion a l'API impossible, reessayez dans un instant."
    else "#{error.class}: #{error.message}".truncate(500)
    end
  end
end
