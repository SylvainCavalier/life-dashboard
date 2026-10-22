module Api
  # Scan de carte de visite : recoit la photo, renvoie les champs d'un contact a
  # relire dans le formulaire. Synchrone, rien n'est stocke (voir BusinessCards).
  class BusinessCardScansController < ApplicationController
    MAX_BYTES = 10.megabytes
    ACCEPTED_TYPES = %w[image/jpeg image/png image/webp].freeze

    def create
      image = params.require(:image)
      unless image.respond_to?(:tempfile)
        return render json: { error: "Aucune photo recue" }, status: :unprocessable_entity
      end
      unless ACCEPTED_TYPES.include?(image.content_type.to_s.split(";").first)
        return render json: { error: "Format d'image non pris en charge (JPEG, PNG ou WebP)" }, status: :unprocessable_entity
      end
      if image.size > MAX_BYTES
        return render json: { error: "Photo trop lourde (#{MAX_BYTES / 1.megabyte} Mo max)" }, status: :unprocessable_entity
      end

      render json: BusinessCards.default.scan(image.tempfile.path)
    rescue BusinessCards::NotConfigured => e
      render json: { error: "Scan indisponible : #{e.message}" }, status: :service_unavailable
    rescue BusinessCards::Error => e
      Rails.logger.warn("[BusinessCards] #{e.message}")
      render json: { error: "La lecture de la carte a echoue : #{e.message}" }, status: :bad_gateway
    end
  end
end
