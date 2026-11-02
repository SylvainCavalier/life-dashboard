module Alfred
  # Execution d'un texto propose par Alfred dans le chat (send_sms), appelee par
  # ActionExecutor apres confirmation de Sylvain. Renvoie la note systeme de la conversation.
  module SmsActions
    module_function

    def execute!(action)
      correspondent = SmsCorrespondent.find(action.data.fetch("correspondent_id"))
      correspondent.send_text!(action.new_attributes.fetch("texte"))
      "Texto envoye a #{correspondent.name}, confirme par Sylvain."
    end
  end
end
