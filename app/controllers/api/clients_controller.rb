class Api::ClientsController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/companies/:company_id/clients
  def index
    @company = Company.find(params[:company_id])
    @clients = @company.clients.ordered
    render json: @clients.map { |c| client_json(c) }
  end

  # POST /api/companies/:company_id/clients
  def create
    @company = Company.find(params[:company_id])
    @client = @company.clients.build(client_params)
    if @client.save
      render json: client_json(@client), status: :created
    else
      render json: { errors: @client.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/companies/:company_id/clients/:id
  def update
    @client = Client.find(params[:id])
    if @client.update(client_params)
      render json: client_json(@client)
    else
      render json: { errors: @client.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/companies/:company_id/clients/:id
  def destroy
    @client = Client.find(params[:id])
    @client.destroy
    head :no_content
  end

  private

  def client_params
    params.permit(
      :name, :email, :phone, :siret, :vat_number,
      :address_line1, :address_line2, :postal_code, :city, :country, :notes
    )
  end

  def client_json(client)
    {
      id: client.id,
      company_id: client.company_id,
      name: client.name,
      email: client.email,
      phone: client.phone,
      siret: client.siret,
      vat_number: client.vat_number,
      address_line1: client.address_line1,
      address_line2: client.address_line2,
      postal_code: client.postal_code,
      city: client.city,
      country: client.country,
      notes: client.notes,
      created_at: client.created_at,
      updated_at: client.updated_at
    }
  end
end
