module Api
  # Conversations avec Alfred. `show` sert aussi de sonde pendant qu'une reponse
  # est en cours : la table alfred_messages fait foi (texte partiel, outils appeles).
  class AlfredConversationsController < ApplicationController
    before_action :set_conversation, only: [:show, :destroy, :message, :export]

    # GET /api/alfred_conversations
    def index
      conversations = AlfredConversation.recent.limit(50)
      render json: conversations.map { |c| { id: c.id, title: c.title, last_message_at: c.last_message_at || c.created_at } }
    end

    # GET /api/alfred_conversations/:id
    def show
      fail_stuck_messages
      render json: conversation_json(@conversation)
    end

    # POST /api/alfred_conversations
    def create
      render json: conversation_json(AlfredConversation.create!), status: :created
    end

    # DELETE /api/alfred_conversations/:id
    def destroy
      @conversation.destroy
      head :no_content
    end

    # GET /api/alfred_conversations/:id/export
    # La conversation en PDF (texte seul), a garder avant de la vider.
    def export
      pdf = ::Alfred::ConversationPdf.new(@conversation)
      send_data pdf.generate, filename: pdf.filename, type: "application/pdf", disposition: "attachment"
    end

    # POST /api/alfred_conversations/:id/message
    def message
      content = params[:content].to_s.strip
      return render json: { error: "Message vide" }, status: :unprocessable_content if content.blank?
      return render json: { error: "Message trop long" }, status: :unprocessable_content if content.length > 8000
      return render json: { error: "Alfred n'est pas configure (#{::Alfred.missing_keys.join(', ')})" }, status: :service_unavailable unless ::Alfred.configured?

      fail_stuck_messages
      return render json: { error: "Alfred repond deja, un instant." }, status: :conflict if @conversation.busy?

      reply = AlfredConversation.transaction do
        @conversation.messages.create!(role: "user", status: "done", content: content)
        @conversation.update!(title: @conversation.title.presence || content.truncate(60), last_message_at: Time.current)
        @conversation.messages.create!(role: "assistant", status: "pending", content: "")
      end
      # Hors transaction : le job ne doit pas demarrer avant le commit.
      AlfredReplyJob.perform_later(reply.id)

      render json: conversation_json(@conversation.reload), status: :created
    end

    private

    def set_conversation
      @conversation = AlfredConversation.find(params[:id])
    end

    # Process redemarre en pleine reponse : le message resterait « en cours » a jamais.
    def fail_stuck_messages
      @conversation.messages.select(&:stuck?).each do |message|
        message.update!(status: "failed", error: "Reponse interrompue (le serveur a redemarre). Reposez la question.")
      end
    end

    def conversation_json(conversation)
      actions = conversation.actions.order(:id).group_by(&:alfred_message_id)
      {
        id: conversation.id,
        title: conversation.title,
        busy: conversation.busy?,
        messages: conversation.messages.map do |message|
          {
            id: message.id, role: message.role, status: message.status, content: message.content,
            steps: message.steps, sources: message.sources, error: message.error, created_at: message.created_at,
            actions: (actions[message.id] || []).map { |action| self.class.action_json(action) }
          }
        end
      }
    end

    def self.action_json(action)
      {
        id: action.id, operation: action.operation, target_model: action.target_model, record_id: action.record_id,
        summary: action.summary, status: action.status, error: action.error,
        attributes: action.new_attributes, before: action.before_attributes
      }
    end
  end
end
