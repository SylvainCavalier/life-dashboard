class Api::HealthProfilesController < ApplicationController
  protect_from_forgery with: :null_session

  # GET /api/health_profile
  def show
    @profile = HealthProfile.first
    if @profile
      render json: @profile
    else
      render json: nil, status: :ok
    end
  end

  # POST /api/health_profile
  def create
    @profile = HealthProfile.new(health_profile_params)
    if @profile.save
      render json: @profile, status: :created
    else
      render json: { errors: @profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/health_profile
  def update
    @profile = HealthProfile.first
    if @profile.nil?
      render json: { errors: ["Profil sante introuvable"] }, status: :not_found
      return
    end

    if @profile.update(health_profile_params)
      render json: @profile
    else
      render json: { errors: @profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def health_profile_params
    params.require(:health_profile).permit(
      :blood_type, :allergies, :current_medications, :medical_history,
      :attending_physician, :attending_physician_phone, :specialists,
      :social_security_number,
      :health_insurance_name, :health_insurance_number, :health_insurance_website,
      :ameli_url
    )
  end
end
