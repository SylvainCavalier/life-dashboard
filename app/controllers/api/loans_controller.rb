module Api
  # Page Prets : objets et argent pretes ou empruntes. `?contact_id=` borne la liste
  # aux prets d'un contact (lien depuis la page Contacts).
  class LoansController < ApplicationController
    PERMITTED = %i[
      direction kind contact_id person_name item amount repaid_amount started_on due_on returned_on notes
    ].freeze

    before_action :set_loan, only: [:update, :destroy]

    # GET /api/loans
    def index
      loans = Loan.ordered.includes(:contact)
      loans = loans.where(contact_id: params[:contact_id]) if params[:contact_id].present?
      render json: loans.map(&:api_attributes)
    end

    def create
      @loan = Loan.new(loan_params)
      if @loan.save
        render json: @loan.api_attributes, status: :created
      else
        render json: { errors: @loan.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @loan.update(loan_params)
        render json: @loan.reload.api_attributes
      else
        render json: { errors: @loan.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @loan.destroy
      head :no_content
    end

    private

    def set_loan
      @loan = Loan.find(params[:id])
    end

    def loan_params
      params.require(:loan).permit(*PERMITTED)
    end
  end
end
