module Api
  class LettersController < ApplicationController
    FORMATS = {
      "pdf" => "application/pdf",
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    }.freeze

    def index
      render json: Letter.ordered.includes(:document).map { |letter| letter_json(letter) }
    end

    def show
      render json: letter_json(Letter.find(params[:id]))
    end

    def create
      letter = Letter.new(letter_params)
      if letter.save
        render json: letter_json(letter), status: :created
      else
        render json: { errors: letter.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      letter = Letter.find(params[:id])
      if letter.update(letter_params)
        render json: letter_json(letter)
      else
        render json: { errors: letter.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      Letter.find(params[:id]).destroy
      head :no_content
    end

    # GET /api/letters/defaults : de quoi pre-remplir une nouvelle lettre depuis « Mon profil ».
    def defaults
      render json: Letter.profile_defaults.merge(mentions: Letter::MENTIONS)
    end

    # POST /api/letters/export (file_format = pdf | docx) : rend l'etat courant du
    # formulaire, enregistre ou non (rien n'est ecrit en base). Pas `format` : Rails
    # le lirait comme le format de la requete.
    def export
      format = params[:file_format].to_s
      return render json: { errors: ["Format inconnu"] }, status: :unprocessable_entity unless FORMATS.key?(format)

      letter = Letter.new(letter_params)
      return render json: { errors: letter.errors.full_messages }, status: :unprocessable_entity unless letter.valid?

      data = format == "pdf" ? letter.to_pdf : letter.to_docx
      send_data data, filename: "#{letter.base_filename}.#{format}", type: FORMATS[format], disposition: "attachment"
    end

    # POST /api/letters/:id/save_to_documents : PDF range (ou remplace) dans la bibliotheque.
    def save_to_documents
      letter = Letter.find(params[:id])
      letter.save_to_documents!
      render json: letter_json(letter.reload)
    end

    private

    def letter_params
      attributes = params.require(:letter).permit(
        :sender, :recipient, :place, :letter_date, :mention, :reference, :subject, :signatory, :include_signature, :footer
      )
      # Le JSON Tiptap est nettoye par Letters::Body (noeuds et marques connus seulement).
      body = params[:letter][:body]
      attributes[:body] = Letters::Body.sanitize(body) if body.present?
      attributes
    end

    def letter_json(letter)
      letter.as_json(except: %i[document_id]).merge(
        "label" => letter.label,
        "document" => letter.document && {
          id: letter.document.id,
          name: letter.document.name,
          updated_at: letter.document.updated_at,
          download_url: download_api_document_path(letter.document)
        }
      )
    end
  end
end
