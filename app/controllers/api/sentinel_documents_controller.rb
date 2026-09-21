module Api
  # Module Sentinelle : détail d'un document (résumé complet et texte intégral).
  # La liste d'une semaine ne porte que les champs légers.
  class SentinelDocumentsController < ApplicationController
    # GET /api/sentinel_documents/:id
    def show
      document = SentinelDocument.includes(:sentinel_source).find(params[:id])
      render json: document.api_attributes(full: true)
    end
  end
end
