module Alfred
  # Execute (ou annule) une ecriture proposee par Alfred, sur confirmation explicite
  # de Sylvain. Tout est reverifie ici : la liste blanche, l'etat de la proposition
  # et le fait que l'enregistrement n'a pas change depuis qu'elle a ete faite.
  class ActionExecutor
    class Stale < StandardError; end

    def initialize(action)
      @action = action
    end

    def confirm!
      @action.with_lock do
        raise ArgumentError, "Cette proposition a deja ete traitee (#{@action.status})" unless @action.proposed?

        record = perform!
        @action.update!(status: "executed", record_id: record.id, resolved_at: Time.current)
        Rails.logger.info "[Alfred::ActionExecutor] action ##{@action.id} executee : #{@action.operation} #{@action.target_model}##{record.id} (#{@action.new_attributes.keys.join(', ')})"
        note("Ecriture confirmee par Sylvain et executee : #{@action.operation} #{@action.target_model} ##{record.id} (#{@action.summary}).")
      end
      @action
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, Stale, DataAccess::Denied => e
      @action.update!(status: "failed", error: e.message.truncate(500), resolved_at: Time.current)
      note("Echec de l'ecriture proposee (#{@action.operation} #{@action.target_model}) : #{e.message.truncate(300)}")
      @action
    end

    def cancel!
      @action.with_lock do
        raise ArgumentError, "Cette proposition a deja ete traitee (#{@action.status})" unless @action.proposed?

        @action.update!(status: "cancelled", resolved_at: Time.current)
        note("Sylvain a annule la proposition : #{@action.operation} #{@action.target_model} (#{@action.summary}). Rien n'a ete ecrit.")
      end
      @action
    end

    private

    def perform!
      klass = DataAccess.writable_class(@action.target_model)
      attributes = @action.new_attributes
      forbidden = attributes.keys - DataAccess.writable_fields(@action.target_model, @action.operation)
      raise DataAccess::Denied, "Champs non modifiables : #{forbidden.join(', ')}" if forbidden.any?

      if @action.operation == "create"
        klass.create!(attributes)
      else
        record = klass.find(@action.record_id)
        ensure_fresh!(record)
        record.update!(attributes)
        record
      end
    end

    # La carte montre un avant/apres : si l'« avant » n'est plus vrai, on n'ecrit pas.
    def ensure_fresh!(record)
      current = DataAccess.serialize(record, @action.before_attributes.keys).as_json
      return if current == @action.before_attributes.as_json

      raise Stale, "l'enregistrement a change depuis la proposition, a reproposer"
    end

    def note(text)
      @action.conversation.messages.create!(role: "event", status: "done", content: text)
      @action.conversation.update!(last_message_at: Time.current)
    end
  end
end
