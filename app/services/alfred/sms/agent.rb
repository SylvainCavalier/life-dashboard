module Alfred
  module Sms
    # Alfred au telephone : une boucle d'outils volontairement separee d'Alfred::Agent.
    # Le texte d'un SMS vient d'un tiers et peut chercher a manipuler le modele : la limite
    # n'est donc pas dans le prompt mais dans ce que l'agent peut atteindre, soit Sms::Tools
    # et les faits autorises (ni corpus, ni query_records, ni memoires, ni Gmail).
    class Agent
      MAX_ITERATIONS = 5
      MAX_TOKENS = 4_000
      HISTORY_MESSAGES = 12
      HISTORY_WINDOW = 48.hours
      FALLBACK = "Je n'ai rien a ajouter pour l'instant.".freeze

      def self.model
        ENV["ALFRED_SMS_MODEL"].presence || ::Alfred.model
      end

      def initialize(inbound, client: nil)
        @inbound = inbound
        @correspondent = inbound.correspondent
        @client = client || Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"], timeout: 60)
      end

      # Renvoie le texte de la reponse. Ne l'envoie pas : c'est le job.
      def call
        messages = history
        text = nil

        MAX_ITERATIONS.times do
          response = @client.messages.create(
            model: self.class.model, max_tokens: MAX_TOKENS,
            system_: Instructions.system_blocks(@correspondent),
            tools: Tools.definitions,
            thinking: { type: "adaptive" },
            output_config: { effort: ENV.fetch("ALFRED_SMS_EFFORT", "low") },
            messages: messages
          )
          messages << { role: :assistant, content: response.content }
          text = response.content.select { |block| block.type.to_s == "text" }.map(&:text).join.strip

          case response.stop_reason.to_s
          when "tool_use" then messages << { role: :user, content: run_tools(response) }
          when "pause_turn" then next
          when "refusal" then return Instructions::REFUSAL
          else break
          end
        end

        text.presence || FALLBACK
      end

      private

      def run_tools(response)
        response.content.select { |block| block.type.to_s == "tool_use" }.map do |block|
          input = block.input.respond_to?(:to_h) ? block.input.to_h.deep_stringify_keys : {}
          result, error = Tools.run(block.name, input, correspondent: @correspondent, inbound: @inbound)
          { type: "tool_result", tool_use_id: block.id, content: result.to_json, is_error: error }
        end
      end

      def history
        past = @correspondent.messages.where(created_at: HISTORY_WINDOW.ago..).where("id <= ?", @inbound.id)
                             .where.not(status: "failed").order(id: :desc).limit(HISTORY_MESSAGES).to_a.reverse
        # L'API exige que le premier message soit celui de l'utilisateur. Un fil peut pourtant
        # commencer par un texto envoye de la part de Sylvain : sans lui, « Ok » ne veut rien dire.
        sent_first, rest = past.partition.with_index { |m, i| !m.inbound? && past.first(i).none?(&:inbound?) }
        turns = rest.map { |m| { role: m.inbound? ? :user : :assistant, content: m.body } }
        return turns if sent_first.empty?

        [{ role: :user, content: "[Note du système, pas de ton correspondant] Tu lui as d'abord envoyé ce(s) texto(s) :\n#{sent_first.map(&:body).join("\n")}" }] + turns
      end
    end
  end
end
