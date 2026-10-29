module Api
  # Page Garanties : objets achetes et date de fin de leur garantie. Le formulaire part
  # en multipart (facture jointe) ; `remove_receipt=1` retire la facture.
  class WarrantiesController < ApplicationController
    PERMITTED = %i[
      name brand model_reference category serial_number store order_number
      purchased_on price duration_months ends_on support_contact notes receipt
    ].freeze

    before_action :set_warranty, only: [:update, :destroy]

    # GET /api/warranties
    def index
      render json: Warranty.ordered.with_attached_receipt.map(&:api_attributes)
    end

    def create
      @warranty = Warranty.new(warranty_params)
      if @warranty.save
        render json: @warranty.api_attributes, status: :created
      else
        render json: { errors: @warranty.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @warranty.update(warranty_params)
        @warranty.receipt.purge_later if remove_receipt?
        render json: @warranty.reload.api_attributes
      else
        render json: { errors: @warranty.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @warranty.destroy
      head :no_content
    end

    private

    def set_warranty
      @warranty = Warranty.find(params[:id])
    end

    # Un nouveau fichier remplace l'ancien de lui-meme : la suppression ne vaut que sans lui.
    def remove_receipt?
      ActiveModel::Type::Boolean.new.cast(params.dig(:warranty, :remove_receipt)) &&
        params.dig(:warranty, :receipt).blank? && @warranty.receipt.attached?
    end

    def warranty_params
      params.require(:warranty).permit(*PERMITTED)
    end
  end
end
