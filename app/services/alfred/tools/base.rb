module Alfred
  module Tools
    class Base
      def initialize(context)
        @context = context
      end

      # Libelle affiche dans le chat pendant l'execution de l'outil.
      def self.step_label(_input) = definition[:name]

      # Outils Gmail : l'erreur remonte au modele comme une erreur d'outil.
      def ensure_gmail!
        raise Gmail::Client::Error, Gmail::NOT_CONFIGURED unless Gmail.enabled?
      end
    end
  end
end
