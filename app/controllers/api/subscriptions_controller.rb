module Api
  class SubscriptionsController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @subscriptions = Subscription.ordered
      render json: @subscriptions
    end

    def create
      @subscription = Subscription.new(subscription_params)
      if @subscription.save
        render json: @subscription, status: :created
      else
        render json: { errors: @subscription.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @subscription = Subscription.find(params[:id])
      if @subscription.update(subscription_params)
        render json: @subscription
      else
        render json: { errors: @subscription.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @subscription = Subscription.find(params[:id])
      @subscription.destroy
      head :no_content
    end

    private

    def subscription_params
      params.require(:subscription).permit(:name, :cost, :billing_cycle, :category, :start_date, :end_date, :url)
    end
  end
end
