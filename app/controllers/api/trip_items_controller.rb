module Api
  class TripItemsController < ApplicationController
    before_action :set_trip
    before_action :set_item, only: [:update, :destroy]

    # POST /api/trips/:trip_id/trip_items
    def create
      item = @trip.trip_items.new(trip_item_params)
      if item.save
        render json: item.api_attributes, status: :created
      else
        render json: { errors: item.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH /api/trips/:trip_id/trip_items/:id
    def update
      if @item.update(trip_item_params)
        render json: @item.api_attributes
      else
        render json: { errors: @item.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /api/trips/:trip_id/trip_items/:id
    def destroy
      @item.destroy
      head :no_content
    end

    private

    def set_trip
      @trip = Trip.find(params[:trip_id])
    end

    # Scope sur le voyage : un item d'un autre voyage repond 404.
    def set_item
      @item = @trip.trip_items.find(params[:id])
    end

    def trip_item_params
      params.require(:trip_item).permit(:day, :kind, :title, :url, :notes, :start_time, :cost, :position)
    end
  end
end
