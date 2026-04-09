class Api::PersonalProfilesController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/personal_profile
  def show
    @profile = PersonalProfile.first
    if @profile
      render json: @profile
    else
      render json: nil, status: :ok
    end
  end

  # POST /api/personal_profile
  def create
    @profile = PersonalProfile.new(profile_params)
    if @profile.save
      render json: @profile, status: :created
    else
      render json: { errors: @profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/personal_profile
  def update
    @profile = PersonalProfile.first
    if @profile.nil?
      render json: { errors: ["Profil introuvable"] }, status: :not_found
      return
    end

    if @profile.update(profile_params)
      render json: @profile
    else
      render json: { errors: @profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:personal_profile).permit(
      :first_name, :last_name, :maiden_name, :birth_date, :birth_city, :birth_country,
      :nationality, :gender,
      :email, :phone, :mobile_phone, :address_line1, :address_line2, :city, :postal_code,
      :state, :country,
      :social_security_number, :passport_number, :passport_expiry, :national_id_number,
      :national_id_expiry, :driver_license_number, :driver_license_expiry, :tax_id,
      :occupation, :employer, :employer_address, :professional_email, :professional_phone,
      :siret_number,
      :marital_status, :spouse_name, :number_of_children, :emergency_contact_name,
      :emergency_contact_phone, :emergency_contact_relationship,
      :bank_name, :iban, :bic
    )
  end
end
