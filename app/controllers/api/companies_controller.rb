class Api::CompaniesController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/companies
  def index
    @companies = Company.ordered
    render json: @companies.map { |c| company_json(c) }
  end

  # GET /api/companies/:id
  def show
    @company = Company.find(params[:id])
    render json: company_json(@company)
  end

  # POST /api/companies
  def create
    @company = Company.new(company_params)
    if @company.save
      render json: company_json(@company), status: :created
    else
      render json: { errors: @company.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/companies/:id
  def update
    @company = Company.find(params[:id])
    if @company.update(company_params)
      render json: company_json(@company)
    else
      render json: { errors: @company.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/companies/:id
  def destroy
    @company = Company.find(params[:id])
    @company.destroy
    head :no_content
  end

  private

  def company_params
    params.permit(
      :name, :legal_form, :siren, :siret, :vat_number, :rcs, :activity, :status,
      :creation_date, :capital, :revenue, :employees_count,
      :address_line1, :address_line2, :postal_code, :city, :country,
      :website, :email, :phone, :notes
    )
  end

  def company_json(company)
    {
      id: company.id,
      name: company.name,
      legal_form: company.legal_form,
      siren: company.siren,
      siret: company.siret,
      vat_number: company.vat_number,
      activity: company.activity,
      status: company.status,
      creation_date: company.creation_date,
      capital: company.capital,
      revenue: company.revenue,
      employees_count: company.employees_count,
      address_line1: company.address_line1,
      address_line2: company.address_line2,
      postal_code: company.postal_code,
      city: company.city,
      country: company.country,
      website: company.website,
      email: company.email,
      phone: company.phone,
      rcs: company.rcs,
      notes: company.notes,
      created_at: company.created_at,
      updated_at: company.updated_at
    }
  end
end
