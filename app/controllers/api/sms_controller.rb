module Api
  # Page Textos : etat de la connexion Twilio, correspondants, demandes en attente et
  # faits qu'Alfred a le droit de donner par texto.
  class SmsController < ApplicationController
    # GET /api/sms
    def show
      render json: overview
    end

    # PATCH /api/sms
    def update
      AlfredSetting.instance.replace_sms_facts!(params[:facts])
      render json: overview
    end

    private

    def overview
      setting = AlfredSetting.instance
      {
        configured: TwilioSms.configured?, number: TwilioSms.number,
        facts: setting.effective_sms_facts, facts_default: AlfredSetting.default_sms_facts,
        correspondents: SmsCorrespondent.ordered.map { |correspondent| correspondent_json(correspondent) },
        pending: pending_requests
      }
    end

    def correspondent_json(correspondent)
      last = correspondent.messages.order(:id).last
      correspondent.slice(:id, :name, :phone, :owner, :enabled, :contact_id).merge(last_message_at: last&.created_at)
    end

    def pending_requests
      AlfredAction.includes(conversation: :sms_correspondent)
                  .joins(:conversation).where.not(alfred_conversations: { sms_correspondent_id: nil })
                  .where(status: "proposed").order(id: :desc).map do |action|
        { id: action.id, conversation_id: action.alfred_conversation_id, summary: action.summary,
          from: action.conversation.sms_correspondent&.name, created_at: action.created_at }
      end
    end
  end
end
