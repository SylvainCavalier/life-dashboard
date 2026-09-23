module Api
  class BudgetEntriesController < ApplicationController
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
      subscriptions = Subscription.all.to_a
      variable_by_month = (1..12).map do |m|
        month_var = variable.for_month(m, year)
        subscription_expense = subscriptions_expense_for(subscriptions, m, year)
        variable_income = month_var.incomes.sum(:amount)
        variable_expense = month_var.expenses.sum(:amount)
        {
          month: m,
          variable_income: variable_income,
          variable_expense: variable_expense,
          # Meme convention que la page Budget : les abonnements sont des charges fixes
          subscription_expense: subscription_expense,
          balance: fixed_income + variable_income - fixed_expense - subscription_expense - variable_expense
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

    # Cout mensuel des abonnements actifs sur le mois (annuel lisse sur 12 mois),
    # transposition de `subscriptionsExpenseForMonth` de BudgetPage.vue.
    def subscriptions_expense_for(subscriptions, month, year)
      month_start = Date.new(year, month, 1)
      month_end = month_start.end_of_month
      subscriptions.sum do |sub|
        next 0 if sub.start_date && sub.start_date > month_end
        next 0 if sub.end_date && sub.end_date < month_start

        sub.billing_cycle == "yearly" ? sub.cost / 12 : sub.cost
      end
    end

    def budget_entry_params
      params.require(:budget_entry).permit(:name, :entry_type, :recurrence, :category, :amount, :month, :year, :notes)
    end
  end
end
