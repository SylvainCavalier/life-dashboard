module Api
  # Page Vehicules : vehicules, avec leur carnet d'entretien imbrique
  # (/vehicles/:id/vehicle_interventions). Les documents passent par /documents avec
  # ?vehicle_id= (domaine `vehicles`), les assurances par les biens assures (InsuredItem#vehicle_id).
  class VehiclesController < ApplicationController
    PERMITTED = %i[
      name vehicle_type status brand model version year registration_number vin first_registration_on
      fuel fiscal_power power_hp engine_displacement color tire_size oil_type
      purchased_on purchase_price purchase_mileage mileage mileage_on technical_inspection_due_on
      service_interval_km service_interval_months sold_on sale_price notes
    ].freeze

    before_action :set_vehicle, only: [:show, :update, :destroy]

    # GET /api/vehicles
    def index
      vehicles = Vehicle.ordered.includes(:vehicle_interventions, :documents)
      render json: vehicles.map(&:api_attributes)
    end

    # GET /api/vehicles/:id
    def show
      render json: @vehicle.api_attributes(full: true)
    end

    def create
      @vehicle = Vehicle.new(vehicle_params)
      if @vehicle.save
        render json: @vehicle.api_attributes(full: true), status: :created
      else
        render json: { errors: @vehicle.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @vehicle.update(vehicle_params)
        render json: @vehicle.api_attributes(full: true)
      else
        render json: { errors: @vehicle.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @vehicle.destroy
      head :no_content
    end

    private

    def set_vehicle
      @vehicle = Vehicle.includes(:vehicle_interventions, :documents, :insurances).find(params[:id])
    end

    def vehicle_params
      params.require(:vehicle).permit(*PERMITTED)
    end
  end
end
