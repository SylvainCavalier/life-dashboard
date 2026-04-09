class Api::DocumentsController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/documents?domain=health
  def index
    @documents = Document.all
    @documents = @documents.for_domain(params[:domain]) if params[:domain].present?
    @documents = @documents.where(category: params[:category]) if params[:category].present?
    @documents = @documents.order(document_date: :desc, created_at: :desc)
    render json: @documents.map { |doc| document_json(doc) }
  end

  # POST /api/documents
  def create
    @document = Document.new(document_params)
    if @document.save
      render json: document_json(@document), status: :created
    else
      render json: { errors: @document.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/documents/:id
  def destroy
    @document = Document.find(params[:id])
    @document.destroy
    head :no_content
  end

  # GET /api/documents/:id/download
  def download
    @document = Document.find(params[:id])
    if @document.file.attached?
      redirect_to rails_blob_path(@document.file, disposition: "attachment"), allow_other_host: true
    else
      render json: { error: "Aucun fichier attache" }, status: :not_found
    end
  end

  # GET /api/documents/categories?domain=health
  def categories
    domain = params[:domain]
    if domain.present? && Document::CATEGORIES.key?(domain)
      render json: { domain: domain, categories: Document::CATEGORIES[domain] }
    else
      render json: { domains: Document::DOMAINS, categories: Document::CATEGORIES }
    end
  end

  private

  def document_params
    params.permit(:domain, :name, :category, :document_date, :notes, :file)
  end

  def document_json(doc)
    {
      id: doc.id,
      domain: doc.domain,
      name: doc.name,
      category: doc.category,
      document_date: doc.document_date,
      notes: doc.notes,
      file_attached: doc.file.attached?,
      file_name: doc.file.attached? ? doc.file.filename.to_s : nil,
      file_size: doc.file.attached? ? doc.file.byte_size : nil,
      file_content_type: doc.file.attached? ? doc.file.content_type : nil,
      download_url: doc.file.attached? ? Rails.application.routes.url_helpers.download_api_document_path(doc) : nil,
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end
end
