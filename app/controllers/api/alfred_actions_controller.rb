module Api
  # Confirmation ou annulation d'une ecriture proposee par Alfred. C'est le SEUL
  # chemin par lequel une proposition touche a la base : le modele n'y a pas acces.
  class AlfredActionsController < ApplicationController
    before_action :set_action

    # POST /api/alfred_actions/:id/confirm
    def confirm
      render json: AlfredConversationsController.action_json(::Alfred::ActionExecutor.new(@action).confirm!)
    rescue ArgumentError => e
      render json: { error: e.message }, status: :conflict
    end

    # POST /api/alfred_actions/:id/cancel
    def cancel
      render json: AlfredConversationsController.action_json(::Alfred::ActionExecutor.new(@action).cancel!)
    rescue ArgumentError => e
      render json: { error: e.message }, status: :conflict
    end

    private

    def set_action
      @action = AlfredAction.find(params[:id])
    end
  end
end
