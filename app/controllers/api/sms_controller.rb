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
      setting = AlfredSetting.instance
      setting.replace_sms_facts!(params[:facts]) if params.key?(:facts)
      change_whitelist(setting) if params.key?(:whitelist_open)
      render json: overview
    end

    private

    def change_whitelist(setting)
      open = ActiveModel::Type::Boolean.new.cast(params[:whitelist_open])
      open ? setting.open_sms_whitelist! : setting.close_sms_whitelist!
      Rails.logger.warn "[Sms] liste blanche #{open ? "ouverte jusqu'au #{setting.sms_open_until}" : 'refermee'} par l'utilisateur ##{current_user.id}"
    end

    def overview
      setting = AlfredSetting.instance
      {
        configured: TwilioSms.configured?, number: TwilioSms.number,
        whitelist_open_until: setting.sms_whitelist_open? ? setting.sms_open_until : nil,
        facts: setting.effective_sms_facts, facts_default: AlfredSetting.default_sms_facts,
        correspondents: SmsCorrespondent.ordered.map { |correspondent| correspondent_json(correspondent) },
        contacts: contact_options,
        pending: pending_requests
      }
    end

    # Tous les contacts, numero renseigne ou non : tries par nom, comme la page Contacts.
    def contact_options
      Contact.ordered.pluck(:id, :last_name, :first_name, :phone, :relationship_type).map do |id, last_name, first_name, phone, relationship|
        { id: id, label: [last_name, first_name].compact_blank.join(" "), name: [first_name, last_name].compact_blank.join(" "),
          phone: phone, relationship: relationship }
      end
    end

    def correspondent_json(correspondent)
      last = correspondent.messages.order(:id).last
      correspondent.slice(:id, :name, :phone, :owner, :enabled, :temporary, :contact_id).merge(last_message_at: last&.created_at)
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
