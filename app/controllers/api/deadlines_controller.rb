module Api
  # Echeances notables, module affiche sous l'agenda. Chaque occurrence est
  # posee dans l'agenda par le modele (voir Deadline).
  class DeadlinesController < ApplicationController
    before_action :set_deadline, only: [:update, :destroy]

    # GET /api/deadlines -> { deadlines: [...], upcoming: [{ deadline_id, date }] (12 mois) }
    def index
      render json: {
        deadlines: Deadline.ordered.map { |deadline| serialize(deadline) },
        upcoming: Deadline.upcoming_occurrences.map { |deadline, date| { deadline_id: deadline.id, date: date } }
      }
    end

    def create
      deadline = Deadline.new(deadline_params)
      if deadline.save
        render json: serialize(deadline), status: :created
      else
        render json: { errors: deadline.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      if @deadline.update(deadline_params)
        render json: serialize(@deadline)
      else
        render json: { errors: @deadline.errors.full_messages }, status: :unprocessable_content
      end
    end

    # Les occurrences a venir quittent l'agenda, les passees y restent.
    def destroy
      @deadline.destroy
      head :no_content
    end

    private

    def set_deadline
      @deadline = Deadline.find(params[:id])
    end

    def deadline_params
      params.require(:deadline).permit(:title, :category, :due_on, :recurrence, :ends_on, :amount, :notes)
    end

    def serialize(deadline)
      deadline.as_json(except: %w[generated_until]).merge(
        "recurring" => deadline.recurring?,
        "category_label" => deadline.category_label,
        "recurrence_label" => deadline.recurrence_label,
        "formatted_amount" => deadline.formatted_amount,
        "next_on" => deadline.next_occurrence
      )
    end
  end
end
