module Api
  # Module Rappels. Les actions done / snooze / seen sont celles de la page et du
  # clic sur une notification (le service worker ouvre /reminders?open=ID).
  class RemindersController < ApplicationController
    before_action :set_reminder, only: [:update, :destroy, :done, :snooze, :seen]

    # GET /api/reminders               -> rappels en cours + 50 derniers termines
    # GET /api/reminders?status=active -> rappels en cours seulement
    def index
      active = Reminder.active.ordered.includes(:remindable).to_a
      completed = params[:status] == "active" ? [] : Reminder.completed.order(completed_at: :desc).limit(50).includes(:remindable).to_a
      render json: (active + completed).map { |reminder| serialize(reminder) }
    end

    def create
      reminder = Reminder.new(reminder_params)
      if reminder.save
        render json: serialize(reminder), status: :created
      else
        render json: { errors: reminder.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @reminder.update(reminder_params)
        render json: serialize(@reminder)
      else
        render json: { errors: @reminder.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @reminder.destroy
      head :no_content
    end

    def done
      @reminder.done!
      render json: serialize(@reminder)
    end

    # POST /api/reminders/:id/snooze  { minutes: 10 } ou { until: "2026-10-04T09:00" }
    def snooze
      target = params[:until].present? ? Time.zone.parse(params[:until].to_s) : params[:minutes].to_i.minutes.from_now
      if target.nil? || target <= Time.current
        return render json: { errors: ["La nouvelle échéance doit être dans le futur"] }, status: :unprocessable_entity
      end

      @reminder.snooze!(target)
      render json: serialize(@reminder)
    end

    # Notification ouverte : les relances s'arretent.
    def seen
      @reminder.acknowledge!
      render json: serialize(@reminder)
    end

    private

    def set_reminder
      @reminder = Reminder.find(params[:id])
    end

    def reminder_params
      params.require(:reminder).permit(:title, :notes, :remind_at, :recurrence, :remindable_type, :remindable_id)
    end

    def serialize(reminder)
      reminder.as_json(except: %w[remindable_type remindable_id]).merge(
        "recurring" => reminder.recurring?,
        "recurrence_label" => reminder.recurrence_label,
        "due" => reminder.due?,
        "remindable" => reminder.remindable_summary
      )
    end
  end
end
