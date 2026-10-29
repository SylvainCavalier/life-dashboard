module Api
  # Biens et personnes couverts par un contrat d'assurance (page de l'assurance).
  class InsuredItemsController < ApplicationController
    before_action :set_insurance
    before_action :set_item, only: [:update, :destroy]

    def create
      item = @insurance.insured_items.new(item_params)
      if item.save
        render json: item.api_attributes, status: :created
      else
        render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @item.update(item_params)
        render json: @item.api_attributes
      else
        render json: { errors: @item.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy
      head :no_content
    end

    private

    def set_insurance
      @insurance = Insurance.find(params[:insurance_id])
    end

    def set_item
      @item = @insurance.insured_items.find(params[:id])
    end

    def item_params
      params.require(:insured_item).permit(:name, :kind, :description, :value, :property_id)
    end
  end
end
