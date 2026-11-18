module Alfred
  module Tools
    class Base
      def initialize(context)
        @context = context
      end

      # Libelle affiche dans le chat pendant l'execution de l'outil.
      def self.step_label(_input) = definition[:name]

      # Resultat d'un outil de proposition. Une action dispensee de confirmation (Alfred::AutoConfirm)
      # est executee ici meme : le modele l'apprend par le resultat et l'annonce comme faite.
      def proposal_result(action, pending_note)
        if AutoConfirm.apply!(action, @context)
          return { action_id: action.id, status: "executee", note: "Executee sans carte a confirmer (reglage de Monsieur) : l'annoncer comme faite." } if action.status == "executed"

          return { action_id: action.id, status: "echec", error: action.error }
        end

        reason = AutoConfirm.enabled?(action) && AutoConfirm.blocked_reason(action, @context)
        pending_note = "#{pending_note} Confirmation demandee malgre le reglage de Monsieur : #{reason}." if reason
        { action_id: action.id, status: "en attente de la confirmation de Monsieur dans le chat", note: pending_note }
      end

      # Outils Gmail : l'erreur remonte au modele comme une erreur d'outil.
      def ensure_gmail!
        raise Gmail::Client::Error, Gmail::NOT_CONFIGURED unless Gmail.enabled?
      end
    end
  end
end
