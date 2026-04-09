class Api::QuotesController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/companies/:company_id/quotes
  def index
    @company = Company.find(params[:company_id])
    @quotes = @company.quotes.ordered.includes(:quote_items)
    render json: @quotes.map { |q| quote_json(q) }
  end

  # POST /api/companies/:company_id/quotes
  def create
    @company = Company.find(params[:company_id])
    @quote = @company.quotes.build(quote_params)
    @quote.issue_date ||= Date.current
    @quote.validity_date ||= Date.current + 30.days

    if @quote.save
      @quote.recalculate_totals!
      generate_pdf_document(@quote)
      render json: quote_json(@quote.reload), status: :created
    else
      render json: { errors: @quote.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/companies/:company_id/quotes/:id/accept
  def accept
    @quote = Quote.find(params[:id])
    @quote.accept!
    generate_pdf_document(@quote)
    render json: quote_json(@quote)
  end

  # PATCH /api/companies/:company_id/quotes/:id/refuse
  def refuse
    @quote = Quote.find(params[:id])
    @quote.refuse!
    generate_pdf_document(@quote)
    render json: quote_json(@quote)
  end

  # GET /api/companies/:company_id/quotes/:id/pdf
  def pdf
    @quote = Quote.includes(:quote_items, :company).find(params[:id])
    pdf_data = Quotes::PdfGenerator.new(@quote).generate
    send_data pdf_data, filename: "#{@quote.number}.pdf", type: "application/pdf", disposition: "inline"
  end

  # DELETE /api/companies/:company_id/quotes/:id
  def destroy
    @quote = Quote.find(params[:id])
    # Remove associated document
    doc = Document.find_by(domain: "companies", category: "quote", name: @quote.number)
    doc&.destroy
    @quote.destroy
    head :no_content
  end

  private

  def quote_params
    params.permit(
      :client_name, :client_email, :client_phone, :client_siret, :client_vat_number,
      :client_address_line1, :client_address_line2, :client_postal_code, :client_city, :client_country,
      :subject, :tva_rate, :issue_date, :validity_date, :notes, :conditions,
      quote_items_attributes: [:id, :description, :quantity, :unit, :unit_price, :position, :discount_type, :discount_value, :_destroy]
    )
  end

  def quote_json(quote)
    {
      id: quote.id,
      company_id: quote.company_id,
      number: quote.number,
      client_name: quote.client_name,
      client_email: quote.client_email,
      client_phone: quote.client_phone,
      client_siret: quote.client_siret,
      client_vat_number: quote.client_vat_number,
      client_address_line1: quote.client_address_line1,
      client_address_line2: quote.client_address_line2,
      client_postal_code: quote.client_postal_code,
      client_city: quote.client_city,
      client_country: quote.client_country,
      subject: quote.subject,
      total_ht: quote.total_ht,
      total_tva: quote.total_tva,
      total_ttc: quote.total_ttc,
      tva_rate: quote.tva_rate,
      status: quote.status,
      issue_date: quote.issue_date,
      validity_date: quote.validity_date,
      notes: quote.notes,
      conditions: quote.conditions,
      items: quote.quote_items.order(:position).map { |item|
        {
          id: item.id,
          description: item.description,
          quantity: item.quantity,
          unit: item.unit,
          unit_price: item.unit_price,
          discount_type: item.discount_type,
          discount_value: item.discount_value,
          total_ht: item.total_ht,
          position: item.position
        }
      },
      pdf_url: Rails.application.routes.url_helpers.pdf_api_company_quote_path(quote.company_id, quote),
      created_at: quote.created_at,
      updated_at: quote.updated_at
    }
  end

  def generate_pdf_document(quote)
    pdf_data = Quotes::PdfGenerator.new(quote).generate

    doc = Document.find_or_initialize_by(domain: "companies", category: "quote", name: quote.number)
    doc.document_date = quote.issue_date
    doc.notes = "Devis #{quote.number} - #{quote.client_name} (#{quote.status})"
    doc.file.attach(
      io: StringIO.new(pdf_data),
      filename: "#{quote.number}.pdf",
      content_type: "application/pdf"
    )
    doc.save!
  end
end
