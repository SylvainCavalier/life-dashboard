module Alfred
  module Tools
    class Base
      def initialize(context)
        @context = context
      end

      # Libelle affiche dans le chat pendant l'execution de l'outil.
      def self.step_label(_input) = definition[:name]
    end
  end
end
