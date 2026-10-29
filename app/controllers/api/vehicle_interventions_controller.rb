module Api
  # Carnet d'entretien d'un vehicule (page du vehicule). Chaque reponse renvoie aussi la
  # fiche du vehicule : une intervention peut en changer le kilometrage et le prochain
  # controle technique.
  class VehicleInterventionsController < ApplicationController
    before_action :set_vehicle
    before_action :set_intervention, only: [:update, :destroy]

    def create
      intervention = @vehicle.vehicle_interventions.new(intervention_params)
      if intervention.save
        render json: payload(intervention), status: :created
      else
        render json: { errors: intervention.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @intervention.update(intervention_params)
        render json: payload(@intervention)
      else
        render json: { errors: @intervention.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @intervention.destroy
      render json: { vehicle: @vehicle.reload.api_attributes(full: true) }
    end

    private

    def set_vehicle
      @vehicle = Vehicle.find(params[:vehicle_id])
    end

    def set_intervention
      @intervention = @vehicle.vehicle_interventions.find(params[:id])
    end

    def payload(intervention)
      { intervention: intervention.api_attributes, vehicle: @vehicle.reload.api_attributes(full: true) }
    end

    def intervention_params
      params.require(:vehicle_intervention)
            .permit(:occurred_on, :kind, :title, :mileage, :cost, :garage, :outcome, :description)
    end
  end
end
