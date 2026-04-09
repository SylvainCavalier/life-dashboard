module Api
  class EventsController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @events = Event.ordered
      render json: @events
    end

    def upcoming
      @events = Event.within_24h
      render json: @events
    end

    def create
      @event = Event.new(event_params)
      if @event.save
        render json: @event, status: :created
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @event = Event.find(params[:id])
      if @event.update(event_params)
        render json: @event
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @event = Event.find(params[:id])
      @event.destroy
      head :no_content
    end

    private

    def event_params
      params.require(:event).permit(
        :title, :description, :event_type, :start_time, :end_time,
        :location, :color, :all_day, :reminder_minutes
      )
    end
  end
end
