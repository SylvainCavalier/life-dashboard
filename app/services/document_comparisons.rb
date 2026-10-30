# Comparateur de documents (page Outils) : texte des deux PDF, puis Mistral en sortie
# structuree. Voir DocumentComparison et DocumentComparisons::Comparator.
module DocumentComparisons
  class Error < StandardError; end
  class NotConfigured < Error; end

  def self.enabled?
    ENV["MISTRAL_API_KEY"].present?
  end

  def self.default
    Comparator.new
  end
end
