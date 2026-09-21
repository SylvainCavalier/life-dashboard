module Api
  class TripsController < ApplicationController
    before_action :set_trip, only: [:show, :update, :destroy, :plan]

    # GET /api/trips
    def index
      trips = Trip.ordered.includes(:trip_plan)
      render json: trips.map { |trip| trip_json(trip) }
    end

    # GET /api/trips/:id
    def show
      render json: trip_json(@trip, full: true)
    end

    # POST /api/trips
    def create
      trip = Trip.new(trip_params)
      if trip.save
        render json: trip_json(trip, full: true), status: :created
      else
        render json: { errors: trip.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH /api/trips/:id
    def update
      if @trip.update(trip_params)
        render json: trip_json(@trip, full: true)
      else
        render json: { errors: @trip.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /api/trips/:id
    def destroy
      @trip.destroy
      head :no_content
    end

    # POST /api/trips/:id/plan
    # Enfile la generation du rapport IA. Repond 202 avec le plan courant,
    # y compris quand une generation est deja en cours.
    def plan
      plan = @trip.generate_plan!
      render json: plan_json(plan), status: :accepted
    end

    private

    def set_trip
      @trip = Trip.includes(:trip_plan, :trip_items).find(params[:id])
    end

    def trip_params
      params.require(:trip).permit(
        :destination, :country_code, :start_date, :end_date,
        :travelers, :departure_city, :status, :notes
      )
    end

    def trip_json(trip, full: false)
      plan = trip.trip_plan
      json = {
        id: trip.id,
        destination: trip.destination,
        country_code: trip.country_code,
        start_date: trip.start_date,
        end_date: trip.end_date,
        travelers: trip.travelers,
        departure_city: trip.departure_city,
        status: trip.status,
        notes: trip.notes,
        duration_days: trip.duration_days,
        past: trip.past?,
        visited: trip.visited?,
        plan_status: plan&.status,
        estimated_total_eur: plan&.done? ? plan.estimated_total_eur : nil,
        created_at: trip.created_at,
        updated_at: trip.updated_at
      }
      return json unless full

      json.merge(
        plan: plan && plan_json(plan),
        items: trip.trip_items.ordered.map(&:api_attributes)
      )
    end

    def plan_json(plan)
      {
        id: plan.id,
        status: plan.status,
        error: plan.error,
        model: plan.model,
        requested_at: plan.requested_at,
        started_at: plan.started_at,
        generated_at: plan.generated_at,
        estimated_total_eur: plan.estimated_total_eur,
        stuck: plan.stuck?,
        outdated: plan.outdated?,
        content: plan.done? ? plan.content : nil
      }
    end
  end
end
