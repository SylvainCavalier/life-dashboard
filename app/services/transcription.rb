# Dictee vocale : l'audio enregistre par le navigateur (MediaRecorder) est
# transcrit par Voxtral (Mistral). Rien n'est conserve : ni l'audio, ni le texte
# cote serveur, le texte repart vers le client qui l'insere ou il veut.
module Transcription
  class Error < StandardError; end
  class NotConfigured < Error; end

  def self.enabled?
    ENV["MISTRAL_API_KEY"].present?
  end

  def self.default
    MistralTranscriber.new
  end
end
