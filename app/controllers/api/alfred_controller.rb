module Api
  # Alfred : disponibilite, etat du corpus, outils et reglages (page Alfred du dashboard).
  class AlfredController < ApplicationController
    # GET /api/alfred
    def show
      render json: overview_json
    end

    # PATCH /api/alfred
    # `custom_instructions` : texte libre ajoute au prompt. `prompt_overrides` : { section => texte },
    # un texte vide (ou null) remet la section au texte par defaut du code.
    def update
      setting = AlfredSetting.instance
      setting.update!(custom_instructions: params[:custom_instructions].to_s.strip.presence) if params.key?(:custom_instructions)
      setting.merge_overrides!(overrides_params) if params.key?(:prompt_overrides)
      render json: overview_json
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    # GET /api/alfred/prompt
    # Le prompt complet tel qu'il partira au modele a la prochaine question.
    def prompt
      render json: { text: ::Alfred::Prompt.full_text }
    end

    # POST /api/alfred/reindex
    # Reindexation complete du corpus (asynchrone). Les empreintes evitent de
    # repayer ce qui n'a pas change.
    def reindex
      return render json: { error: "MISTRAL_API_KEY manquante" }, status: :service_unavailable unless ::Alfred.corpus_configured?

      AlfredReindexJob.perform_later
      render json: { enqueued: true }, status: :accepted
    end

    private

    def overrides_params
      raw = params[:prompt_overrides]
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      raw.to_h.transform_values { |v| v.is_a?(String) ? v : nil }
    end

    def overview_json
      setting = AlfredSetting.instance
      {
        available: ::Alfred.configured?,
        missing_keys: ::Alfred.missing_keys,
        model: ::Alfred.model,
        effort: ENV.fetch("ALFRED_EFFORT", "medium"),
        history_messages: ::Alfred::Agent::HISTORY_MESSAGES,
        custom_instructions: setting.custom_instructions,
        prompt_sections: ::Alfred::Prompt::SECTIONS.map do |section|
          {
            key: section[:key], title: section[:title], help: section[:help],
            default: ::Alfred::Prompt.default_for(section[:key]),
            override: setting.override_for(section[:key])
          }
        end,
        tools: ::Alfred::Tools.catalog,
        integrations: {
          anthropic: ::Alfred.llm_configured?,
          mistral: ::Alfred.corpus_configured?,
          gmail: Gmail.enabled?,
          gmail_user: Gmail.user,
          google_calendar: GoogleCalendar.enabled?
        },
        readable_models: ::Alfred::DataAccess::READABLE.keys,
        writable_models: ::Alfred::DataAccess::WRITABLE.keys,
        corpus: {
          chunks: AlfredChunk.count,
          records: AlfredIndexEntry.where(status: "indexed").count,
          failed: AlfredIndexEntry.failed.count,
          last_indexed_at: AlfredIndexEntry.maximum(:indexed_at)
        }
      }
    end
  end
end
