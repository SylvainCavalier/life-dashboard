# Import d'un contrat d'assurance (page Assurances) : texte du fichier, puis Mistral en
# sortie structuree. Voir InsuranceImport et InsuranceImports::Extractor.
module InsuranceImports
  class Error < StandardError; end
  class NotConfigured < Error; end

  def self.enabled?
    ENV["MISTRAL_API_KEY"].present?
  end

  def self.default
    Extractor.new
  end
end
