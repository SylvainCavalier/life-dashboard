class Api::PropertiesController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/properties
  def index
    @properties = Property.ordered.with_attached_photos
    render json: @properties.map { |p| property_json(p) }
  end

  # GET /api/properties/:id
  def show
    @property = Property.with_attached_photos.find(params[:id])
    render json: property_json(@property)
  end

  # POST /api/properties
  def create
    @property = Property.new(property_params)
    if @property.save
      render json: property_json(@property), status: :created
    else
      render json: { errors: @property.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/properties/:id
  def update
    @property = Property.find(params[:id])
    if @property.update(property_params)
      render json: property_json(@property)
    else
      render json: { errors: @property.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/properties/:id
  def destroy
    @property = Property.find(params[:id])
    @property.destroy
    head :no_content
  end

  # POST /api/properties/:id/photos
  def add_photos
    @property = Property.find(params[:id])
    @property.photos.attach(params[:photos])
    render json: property_json(@property)
  end

  # DELETE /api/properties/:id/photos/:photo_id
  def remove_photo
    @property = Property.find(params[:id])
    photo = @property.photos.find(params[:photo_id])
    photo.purge
    render json: property_json(@property)
  end

  private

  def property_params
    params.permit(
      :name, :property_type, :address_line1, :address_line2, :postal_code, :city, :country,
      :surface, :rooms, :bedrooms, :bathrooms, :floors, :construction_year,
      :purchase_date, :purchase_price, :current_value,
      :loan_remaining, :monthly_payment, :months_remaining,
      :monthly_charges, :property_tax, :rental_income, :rented, :tenant_name, :notes,
      photos: []
    )
  end

  def property_json(property)
    {
      id: property.id,
      name: property.name,
      property_type: property.property_type,
      address_line1: property.address_line1,
      address_line2: property.address_line2,
      postal_code: property.postal_code,
      city: property.city,
      country: property.country,
      surface: property.surface,
      rooms: property.rooms,
      bedrooms: property.bedrooms,
      bathrooms: property.bathrooms,
      floors: property.floors,
      construction_year: property.construction_year,
      purchase_date: property.purchase_date,
      purchase_price: property.purchase_price,
      current_value: property.current_value,
      loan_remaining: property.loan_remaining,
      monthly_payment: property.monthly_payment,
      months_remaining: property.months_remaining,
      monthly_charges: property.monthly_charges,
      property_tax: property.property_tax,
      rental_income: property.rental_income,
      rented: property.rented,
      tenant_name: property.tenant_name,
      notes: property.notes,
      photos: property.photos.map { |photo|
        {
          id: photo.id,
          url: Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true),
          filename: photo.filename.to_s,
          content_type: photo.content_type
        }
      },
      created_at: property.created_at,
      updated_at: property.updated_at
    }
  end
end
