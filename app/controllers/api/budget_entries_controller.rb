module Api
  class BudgetEntriesController < ApplicationController
    protect_from_forgery with: :null_session

    def index
      @entries = BudgetEntry.ordered
      render json: @entries
    end

    def create
      @entry = BudgetEntry.new(budget_entry_params)
      if @entry.save
        render json: @entry, status: :created
      else
        render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      @entry = BudgetEntry.find(params[:id])
      if @entry.update(budget_entry_params)
        render json: @entry
      else
        render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @entry = BudgetEntry.find(params[:id])
      @entry.destroy
      head :no_content
    end

    def summary
      year = params[:year]&.to_i || Date.current.year

      fixed = BudgetEntry.fixed
      variable = BudgetEntry.variable.where(year: year)

      fixed_income = fixed.incomes.sum(:amount)
      fixed_expense = fixed.expenses.sum(:amount)
      variable_by_month = (1..12).map do |m|
        month_var = variable.for_month(m, year)
        {
          month: m,
          variable_income: month_var.incomes.sum(:amount),
          variable_expense: month_var.expenses.sum(:amount)
        }
      end

      render json: {
        year: year,
        fixed_income: fixed_income,
        fixed_expense: fixed_expense,
        months: variable_by_month
      }
    end

    private

    def budget_entry_params
      params.require(:budget_entry).permit(:name, :entry_type, :recurrence, :category, :amount, :month, :year, :notes)
    end
  end
end
