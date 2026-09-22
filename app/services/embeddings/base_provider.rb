module Embeddings
  # Contrat : `embed(texts:)` renvoie un vecteur par texte, dans l'ordre d'entree.
  class BaseProvider
    def embed(texts:)
      raise NotImplementedError
    end

    def name
      self.class.name.demodulize.sub(/Provider\z/, "").downcase
    end
  end
end
