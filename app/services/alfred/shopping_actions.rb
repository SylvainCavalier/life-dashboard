module Alfred
  # Execution des propositions sur la liste de courses (shopping_add, shopping_remove,
  # shopping_clear), appelee par ActionExecutor apres confirmation de Sylvain. Renvoie
  # le texte de la note systeme laissee dans la conversation.
  #
  # Pas de controle de fraicheur comme pour une ecriture : la liste bouge depuis la page
  # (articles coches, ajoutes) et c'est sans consequence. Un article deja ajoute entre-temps
  # est ignore, un article deja retire aussi ; vider la liste la vide telle qu'elle est.
  module ShoppingActions
    module_function

    def execute!(action)
      case action.operation
      when "shopping_add" then add!(action)
      when "shopping_remove" then remove!(action)
      when "shopping_clear" then clear!(action)
      else raise ArgumentError, "operation de liste de courses inconnue : #{action.operation}"
      end
    end

    def add!(action)
      added, skipped = ShoppingItem.add_names(action.data.fetch("items"))
      text = "Liste de courses : #{added.size} article(s) ajoute(s), confirme par Sylvain (#{added.map(&:name).join(', ')})."
      skipped.any? ? "#{text} Deja presents : #{skipped.join(', ')}." : text
    end

    def remove!(action)
      removed = ShoppingItem.where(id: action.data.fetch("ids")).destroy_all
      "Liste de courses : #{removed.size} article(s) retire(s), confirme par Sylvain (#{removed.map(&:name).join(', ')})."
    end

    def clear!(_action)
      count = ShoppingItem.clear!
      "Liste de courses videe (#{count} article(s)), confirme par Sylvain."
    end
  end
end
