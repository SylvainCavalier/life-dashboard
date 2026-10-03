module Alfred
  # Execution des propositions de memoire (remember, revise_memory, forget),
  # appelee par ActionExecutor apres confirmation de Sylvain. Renvoie le texte de
  # la note systeme laissee dans la conversation, et l'id de la memoire.
  #
  # Le payload porte deux formes : `memory` / `snapshot` (colonnes, pour ecrire et
  # verifier) et `attributes` / `before` (libelles francais, pour la carte du chat).
  module MemoryActions
    FIELDS = %w[content category subject_type subject_id].freeze

    module_function

    def execute!(action)
      case action.operation
      when "remember" then remember!(action)
      when "revise_memory" then revise!(action)
      when "forget" then forget!(action)
      else raise ArgumentError, "operation de memoire inconnue : #{action.operation}"
      end
    end

    def snapshot(memory)
      memory.attributes.slice(*FIELDS)
    end

    # Ce qu'affiche la carte : le fait, sa categorie, la fiche liee.
    def display(values)
      return {} if values.blank?

      shown = { "fait" => values["content"], "categorie" => AlfredMemory::CATEGORIES[values["category"]] }
      shown["fiche"] = "#{values['subject_type']}##{values['subject_id']}" if values["subject_type"].present?
      shown
    end

    # Correction : la carte ne montre que ce qui change.
    def display_diff(before, after)
      old = display(before)
      new = display(after)
      keys = (old.keys | new.keys).reject { |key| old[key] == new[key] }
      [keys.index_with { |key| new[key] }, keys.index_with { |key| old[key] }]
    end

    def remember!(action)
      memory = AlfredMemory.create!(action.data.fetch("memory"))
      ["Memoire ##{memory.id} enregistree, confirmee par Sylvain (#{action.summary}). Elle figure dans ton prompt des le prochain message.",
       memory.id]
    end

    def revise!(action)
      memory = fresh!(action)
      memory.update!(action.data.fetch("memory"))
      ["Memoire ##{memory.id} corrigee, confirmee par Sylvain (#{action.summary}).", memory.id]
    end

    def forget!(action)
      memory = fresh!(action)
      memory.destroy!
      ["Memoire ##{memory.id} oubliee, confirmee par Sylvain (#{action.summary}).", memory.id]
    end

    # Sylvain a pu modifier la memoire depuis la page Alfred entre-temps.
    def fresh!(action)
      memory = AlfredMemory.find(action.record_id)
      return memory if snapshot(memory).as_json == action.data.fetch("snapshot").as_json

      raise ActionExecutor::Stale, "la memoire a change depuis la proposition, a reproposer"
    end
  end
end
