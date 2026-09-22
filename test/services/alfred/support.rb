# Fournisseur d'embeddings factice : aucun appel reseau. Chaque texte recoit le
# vecteur declare pour le premier motif qu'il contient, sinon un vecteur neutre.
module AlfredTestSupport
  DIMENSIONS = Embeddings::DIMENSIONS

  def self.axis(*weights)
    vector = Array.new(DIMENSIONS, 0.0)
    weights.each_with_index { |weight, index| vector[index] = weight.to_f }
    vector
  end

  class FakeEmbeddings < Embeddings::BaseProvider
    attr_reader :calls

    def initialize(mapping = {})
      @mapping = mapping
      @calls = 0
    end

    def embed(texts:)
      @calls += 1
      Array(texts).map do |text|
        match = @mapping.find { |pattern, _| text.include?(pattern) }
        match ? match.last : AlfredTestSupport.axis(0, 0, 0, 1)
      end
    end
  end
end
