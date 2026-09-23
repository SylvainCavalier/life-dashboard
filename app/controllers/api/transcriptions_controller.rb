module Api
  # Dictee vocale : recoit un enregistrement du navigateur, renvoie le texte.
  # Synchrone (le mode dicte est court, borne cote client a MAX_SECONDS) ;
  # rien n'est stocke.
  class TranscriptionsController < ApplicationController
    MAX_BYTES = 20.megabytes
    # Chrome produit du webm/opus, Safari du mp4/aac ; certains navigateurs
    # etiquettent l'enregistrement en video/* alors qu'il n'y a que du son.
    ACCEPTED_TYPES = %r{\A(audio/[\w.+-]+|video/(webm|mp4))\z}

    def create
      audio = params.require(:audio)
      unless audio.respond_to?(:tempfile)
        return render json: { error: "Aucun enregistrement recu" }, status: :unprocessable_entity
      end

      content_type = audio.content_type.to_s.split(";").first
      unless ACCEPTED_TYPES.match?(content_type)
        return render json: { error: "Format audio non pris en charge (#{content_type.presence || 'inconnu'})" }, status: :unprocessable_entity
      end
      if audio.size > MAX_BYTES
        return render json: { error: "Enregistrement trop long (#{MAX_BYTES / 1.megabyte} Mo max)" }, status: :unprocessable_entity
      end

      text = Transcription.default.transcribe(io: audio.tempfile, filename: audio.original_filename.presence || "dictee", content_type: content_type)
      render json: { text: text }
    rescue Transcription::NotConfigured => e
      render json: { error: "Dictee indisponible : #{e.message}" }, status: :service_unavailable
    rescue Transcription::Error => e
      Rails.logger.warn("[Transcription] #{e.message}")
      render json: { error: "La transcription a echoue, reessayez." }, status: :bad_gateway
    end
  end
end
