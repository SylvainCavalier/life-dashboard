# Registre des domaines de veille de Sentinelle. Chaque domaine est isolé :
# ses sources, son classifieur, ses catégories et ses prompts vivent dans sa
# propre classe (app/services/sentinel/domains/). Les tables sont communes mais
# toutes les lectures sont bornées par `domain`, donc deux domaines ne se
# mélangent jamais, ni dans la collecte ni dans les synthèses.
#
# Ajouter un domaine = écrire une sous-classe de Sentinel::Domains::Base et
# l'inscrire ici. L'onglet apparaît tout seul dans l'interface.
module Sentinel
  module Domains
    class UnknownDomain < StandardError; end

    # Noms de classes et non classes : le rechargement du code en développement
    # remplace les constantes, une référence figée deviendrait obsolète.
    REGISTRY = %w[
      Sentinel::Domains::LaborLaw
      Sentinel::Domains::Disinformation
    ].freeze

    def self.all
      REGISTRY.map { |name| name.constantize.new }
    end

    def self.keys
      all.map(&:key)
    end

    def self.find(key)
      all.find { |domain| domain.key == key.to_s }
    end

    def self.find!(key)
      find(key) || raise(UnknownDomain, "Domaine de veille inconnu : #{key.inspect} (connus : #{keys.join(', ')})")
    end
  end
end
