module Api
  # Liste blanche des numeros autorises et fil des textos de chacun.
  class SmsCorrespondentsController < ApplicationController
    before_action :set_correspondent, only: [:update, :destroy, :messages, :send_text]

    # POST /api/sms_correspondents
    def create
      correspondent = SmsCorrespondent.new(correspondent_params)
      return render json: correspondent, status: :created if correspondent.save

      render json: { errors: correspondent.errors.full_messages }, status: :unprocessable_content
    end

    # PATCH /api/sms_correspondents/:id
    def update
      return render json: @correspondent if @correspondent.update(correspondent_params)

      render json: { errors: @correspondent.errors.full_messages }, status: :unprocessable_content
    end

    # DELETE /api/sms_correspondents/:id (le fil de textos part avec lui)
    def destroy
      @correspondent.destroy
      head :no_content
    end

    # GET /api/sms_correspondents/:id/messages
    def messages
      render json: messages_json
    end

    # POST /api/sms_correspondents/:id/send_text
    def send_text
      body = params[:body].to_s.strip
      return render json: { error: "Texto vide" }, status: :unprocessable_content if body.empty?
      return render json: { error: "Texto trop long (#{SmsMessage::MAX_LENGTH} caracteres au plus)" }, status: :unprocessable_content if body.length > SmsMessage::MAX_LENGTH

      @correspondent.send_text!(body)
      render json: messages_json, status: :created
    rescue TwilioSms::Error => e
      render json: { error: e.message }, status: :bad_gateway
    end

    private

    def set_correspondent
      @correspondent = SmsCorrespondent.find(params[:id])
    end

    def correspondent_params
      params.require(:sms_correspondent).permit(:name, :phone, :contact_id, :owner, :enabled)
    end

    def messages_json
      @correspondent.messages.chronological.last(100).map do |message|
        message.slice(:id, :direction, :body, :status, :error, :created_at)
      end
    end
  end
end
