# Scan de carte de visite (page Contacts) : la photo prise dans le navigateur est
# ocerisee par Mistral OCR, puis un modele Mistral range le texte dans les champs d'un
# Contact. Rien n'est conserve : ni l'image, ni le texte ; le formulaire du contact
# arrive pre-rempli et c'est Sylvain qui enregistre apres relecture.
module BusinessCards
  class Error < StandardError; end
  class NotConfigured < Error; end

  def self.enabled?
    ENV["MISTRAL_API_KEY"].present?
  end

  def self.default
    Scanner.new
  end
end
