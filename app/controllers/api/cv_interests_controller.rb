module Api
  class CvInterestsController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      render json: CvInterest.ordered
    end

    def create
      interest = CvInterest.new(interest_params)
      if interest.save
        render json: interest, status: :created
      else
        render json: { errors: interest.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      interest = CvInterest.find(params[:id])
      if interest.update(interest_params)
        render json: interest
      else
        render json: { errors: interest.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      CvInterest.find(params[:id]).destroy
      head :no_content
    end

    private

    def interest_params
      params.require(:cv_interest).permit(:name, :description, :position)
    end
  end
end
