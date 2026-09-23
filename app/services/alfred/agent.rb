module Alfred
  # La boucle d'agent : envoie la conversation a Claude, execute les outils qu'il
  # demande, recommence jusqu'a la reponse finale. Le texte est diffuse au fil de
  # l'eau dans `alfred_messages.content` (la table fait foi, l'interface la sonde).
  #
  # Specifique a l'API Anthropic par construction (blocs tool_use / tool_result,
  # reflexion adaptative) : seule la couche embeddings est interchangeable.
  class Agent
    MAX_ITERATIONS = 12
    MAX_TOKENS = 16_000
    FLUSH_INTERVAL = 0.35 # secondes entre deux ecritures du texte partiel
    # Tours rejoues. L'historique ne contient que du texte (questions, reponses,
    # notes systeme) : les resultats d'outils des tours passes ne sont pas rejoues,
    # Alfred relit la base, qui a pu changer entre-temps.
    HISTORY_MESSAGES = ENV.fetch("ALFRED_HISTORY_MESSAGES", "16").to_i

    def initialize(message, client: nil)
      @message = message
      @conversation = message.conversation
      @client = client || Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"], timeout: 120)
      @context = Tools::Context.new(conversation: @conversation, message: @message, seen: Set.new)
      @text = +""
      @usage = { input: 0, output: 0, cached: 0 }
    end

    def call
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      messages = history

      MAX_ITERATIONS.times do
        response = stream_turn(messages)
        track_usage(response)
        messages << { role: :assistant, content: response.content }

        case response.stop_reason
        when :tool_use
          messages << { role: :user, content: run_tools(response) }
        when :pause_turn
          next
        when :refusal
          @text << "\n\nJe crains de ne pouvoir donner suite a cette demande, Monsieur."
          break
        when :max_tokens
          @text << "\n\n(Reponse interrompue : limite de longueur atteinte.)"
          break
        else
          break
        end
      end

      content, sources = Citations.extract(@text, seen: @context.seen)
      @message.update!(
        status: "done", content: content.strip.presence || "Je n'ai rien a ajouter, Monsieur.", sources: sources,
        model: Alfred.model, input_tokens: @usage[:input], output_tokens: @usage[:output], cached_tokens: @usage[:cached],
        latency_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      )
    end

    private

    def stream_turn(messages)
      stream = @client.messages.stream(
        model: Alfred.model,
        max_tokens: MAX_TOKENS,
        system_: Prompt.system_blocks,
        tools: Tools.definitions,
        thinking: { type: "adaptive" },
        output_config: { effort: ENV.fetch("ALFRED_EFFORT", "medium") },
        messages: messages
      )

      @text << "\n\n" if @text.present? && !@text.end_with?("\n\n")
      last_flush = 0.0
      stream.text.each do |delta|
        @text << delta
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        next if now - last_flush < FLUSH_INTERVAL

        last_flush = now
        @message.update_columns(content: encrypted(@text), updated_at: Time.current)
      end
      stream.accumulated_message
    end

    # update_columns court-circuite le chiffrement declare sur le modele.
    def encrypted(text)
      AlfredMessage.type_for_attribute(:content).serialize(text)
    end

    # Tous les tool_result dans UN seul message utilisateur, erreurs comprises.
    def run_tools(response)
      response.content.select { |block| block.type == :tool_use }.map do |block|
        input = block.input.respond_to?(:to_h) ? block.input.to_h.deep_stringify_keys : {}
        add_step(block.name, input)
        result, error = Tools.run(block.name, input, @context)
        { type: "tool_result", tool_use_id: block.id, content: result.to_json, is_error: error }
      end
    end

    def add_step(name, input)
      label = Tools.find(name)&.step_label(input) || name
      @message.update!(steps: @message.steps + [{ "tool" => name, "label" => label, "at" => Time.current.iso8601 }])
    end

    def track_usage(response)
      usage = response.usage or return
      @usage[:input] += usage.input_tokens.to_i + usage.cache_creation_input_tokens.to_i + usage.cache_read_input_tokens.to_i
      @usage[:output] += usage.output_tokens.to_i
      @usage[:cached] += usage.cache_read_input_tokens.to_i
    end

    def history
      past = @conversation.messages.where(status: "done").where("id < ?", @message.id).last(HISTORY_MESSAGES)
      # L'API exige que le premier message soit celui de l'utilisateur.
      past = past.drop_while { |m| m.role != "user" }
      past.filter_map do |m|
        next if m.content.blank?

        case m.role
        when "user" then { role: :user, content: m.content }
        when "assistant" then { role: :assistant, content: m.content }
        when "event" then { role: :user, content: "[Systeme] #{m.content}" }
        end
      end
    end
  end
end
