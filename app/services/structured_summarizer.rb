# Base des syntheses de transcriptions par Claude, en sortie structuree (JSON Schema) :
# Reunions (Meetings::Summarizer) et outil Videos (VideoTranscripts::Summarizer). Les
# sous-classes fournissent le prompt et le schema ; aucune n'ecrit en base (c'est le job).
class StructuredSummarizer
  class Error < StandardError; end

  MAX_TOKENS = 16_000

  # Surcharges par sous-classe : modele et effort ont leurs propres variables d'environnement.
  def self.model
    Alfred.model
  end

  def self.effort
    "medium"
  end

  def initialize(client: nil)
    @client = client
  end

  private

  # Renvoie [contenu (Hash), modele effectivement utilise].
  def request(system:, schema:, prompt:)
    message = client.messages.create(
      model: self.class.model,
      max_tokens: self.class::MAX_TOKENS,
      system: system,
      thinking: { type: "adaptive" },
      output_config: { effort: self.class.effort.to_sym, format_: { type: :json_schema, schema: schema } },
      messages: [{ role: "user", content: prompt }]
    )
    raise Error, "Synthese refusee par le modele" if message.stop_reason.to_s == "refusal"
    raise Error, "Synthese tronquee (max_tokens)" if message.stop_reason.to_s == "max_tokens"

    text = message.content.select { |block| block.type.to_s == "text" }.map(&:text).join
    [JSON.parse(text), message.model.to_s]
  rescue JSON::ParserError
    raise Error, "Synthese illisible (JSON invalide)"
  end

  def client
    @client ||= begin
      raise Error, "ANTHROPIC_API_KEY absente de l'environnement" if ENV["ANTHROPIC_API_KEY"].blank?

      Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"], timeout: 300)
    end
  end

  # Seuls les codes presents dans la transcription sont retenus (garde anti-hallucination).
  def speaker_names_from(content, known)
    Array(content["speakers"]).each_with_object({}) do |entry, names|
      speaker = entry["speaker"].to_s
      name = entry["name"].to_s.strip
      names[speaker] = name if known.include?(speaker) && name.present?
    end
  end
end
