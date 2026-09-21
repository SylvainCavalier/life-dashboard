# Appel OpenAI à sortie structurée, partagé par le résumé de document et la
# synthèse hebdomadaire (même patron que Trips::PlanGenerationService, sans
# outil de recherche web : Sentinelle ne résume que ce qu'elle a collecté).
# Pur : aucun accès à la base, client injectable pour les tests.
module Sentinel
  class Llm
    class Error < StandardError; end
    class EmptyResponse < Error; end

    DEFAULT_MODEL = "gpt-5.6-sol"
    # GoodJob tourne dans le dyno web : pas d'appel qui immobilise un fil pendant 10 minutes.
    TIMEOUT_SECONDS = 120

    # Synthèse : OPENAI_SENTINEL_MODEL. Résumés par document (le gros du volume) :
    # OPENAI_SENTINEL_SUMMARY_MODEL, pour pouvoir y mettre un modèle moins cher.
    def self.digest_model
      ENV.fetch("OPENAI_SENTINEL_MODEL", DEFAULT_MODEL)
    end

    def self.summary_model
      ENV.fetch("OPENAI_SENTINEL_SUMMARY_MODEL") { digest_model }
    end

    def self.configured?
      ENV["OPENAI_API_KEY"].present?
    end

    def initialize(client: nil)
      @client = client
    end

    # Renvoie { content: Hash (clés String), model: String }.
    def call(model:, instructions:, input:, schema:)
      response = client.responses.create(model: model, instructions: instructions, input: input, text: schema)
      { content: extract_content(response), model: response.model.to_s }
    end

    private

    def client
      @client ||= OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"), timeout: TIMEOUT_SECONDS)
    end

    def extract_content(response)
      contents = response.output.grep(OpenAI::Models::Responses::ResponseOutputMessage).flat_map(&:content)

      refusal = contents.grep(OpenAI::Models::Responses::ResponseOutputRefusal).first
      raise EmptyResponse, "Le modèle a refusé de répondre : #{refusal.refusal}" if refusal

      parsed = contents.grep(OpenAI::Models::Responses::ResponseOutputText).filter_map(&:parsed).first
      raise EmptyResponse, "Réponse vide ou non structurée du modèle" if parsed.nil?

      JSON.parse(parsed.to_json)
    end
  end
end
