class Api::InvoicesController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/companies/:company_id/invoices
  def index
    @company = Company.find(params[:company_id])
    @invoices = @company.invoices.ordered.includes(:invoice_items)
    render json: @invoices.map { |inv| invoice_json(inv) }
  end

  # POST /api/companies/:company_id/invoices
  def create
    @company = Company.find(params[:company_id])
    @invoice = @company.invoices.build(invoice_params)
    @invoice.issue_date ||= Date.current
    @invoice.due_date ||= Date.current + 30.days

    if @invoice.save
      @invoice.recalculate_totals!
      generate_pdf_document(@invoice)
      render json: invoice_json(@invoice.reload), status: :created
    else
      render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /api/companies/:company_id/invoices/from_quote/:quote_id
  def from_quote
    @company = Company.find(params[:company_id])
    @quote = @company.quotes.find(params[:quote_id])

    if @quote.status != "accepted"
      render json: { errors: ["Le devis doit etre accepte pour generer une facture"] }, status: :unprocessable_entity
      return
    end

    @invoice = Invoice.from_quote(@quote)

    if @invoice.save
      @invoice.recalculate_totals!
      generate_pdf_document(@invoice)
      render json: invoice_json(@invoice.reload), status: :created
    else
      render json: { errors: @invoice.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/companies/:company_id/invoices/:id/mark_paid
  def mark_paid
    @invoice = Invoice.find(params[:id])
    @invoice.mark_as_paid!(payment_method: params[:payment_method])
    generate_pdf_document(@invoice)
    render json: invoice_json(@invoice)
  end

  # GET /api/companies/:company_id/invoices/:id/pdf
  def pdf
    @invoice = Invoice.includes(:invoice_items, :company).find(params[:id])
    pdf_data = Invoices::PdfGenerator.new(@invoice).generate
    send_data pdf_data, filename: "#{@invoice.number}.pdf", type: "application/pdf", disposition: "inline"
  end

  # DELETE /api/companies/:company_id/invoices/:id
  def destroy
    @invoice = Invoice.find(params[:id])
    doc = Document.find_by(domain: "companies", category: "invoice", name: @invoice.number)
    doc&.destroy
    @invoice.destroy
    head :no_content
  end

  private

  def invoice_params
    params.permit(
      :client_name, :client_email, :client_phone, :client_siret, :client_vat_number,
      :client_address_line1, :client_address_line2, :client_postal_code, :client_city, :client_country,
      :subject, :tva_rate, :issue_date, :due_date, :notes, :conditions,
      invoice_items_attributes: [:id, :description, :quantity, :unit, :unit_price, :position, :discount_type, :discount_value, :_destroy]
    )
  end

  def invoice_json(invoice)
    {
      id: invoice.id,
      company_id: invoice.company_id,
      quote_id: invoice.quote_id,
      number: invoice.number,
      client_name: invoice.client_name,
      client_email: invoice.client_email,
      client_phone: invoice.client_phone,
      client_siret: invoice.client_siret,
      client_vat_number: invoice.client_vat_number,
      client_address_line1: invoice.client_address_line1,
      client_address_line2: invoice.client_address_line2,
      client_postal_code: invoice.client_postal_code,
      client_city: invoice.client_city,
      client_country: invoice.client_country,
      subject: invoice.subject,
      total_ht: invoice.total_ht,
      total_tva: invoice.total_tva,
      total_ttc: invoice.total_ttc,
      tva_rate: invoice.tva_rate,
      status: invoice.status,
      payment_method: invoice.payment_method,
      paid_at: invoice.paid_at,
      issue_date: invoice.issue_date,
      due_date: invoice.due_date,
      notes: invoice.notes,
      conditions: invoice.conditions,
      items: invoice.invoice_items.order(:position).map { |item|
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
      pdf_url: Rails.application.routes.url_helpers.pdf_api_company_invoice_path(invoice.company_id, invoice),
      created_at: invoice.created_at,
      updated_at: invoice.updated_at
    }
  end

  def generate_pdf_document(invoice)
    pdf_data = Invoices::PdfGenerator.new(invoice).generate

    doc = Document.find_or_initialize_by(domain: "companies", category: "invoice", name: invoice.number)
    doc.document_date = invoice.issue_date
    doc.notes = "Facture #{invoice.number} - #{invoice.client_name} (#{invoice.status})"
    doc.file.attach(
      io: StringIO.new(pdf_data),
      filename: "#{invoice.number}.pdf",
      content_type: "application/pdf"
    )
    doc.save!
  end
end
