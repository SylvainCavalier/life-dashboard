module Api
  # Abonnements Web Push des appareils (voir PushNotifications). La cle publique
  # VAPID est renvoyee par l'index : le navigateur en a besoin pour s'abonner.
  class PushSubscriptionsController < ApplicationController
    def index
      render json: {
        configured: PushNotifications.configured?,
        public_key: PushNotifications.public_key,
        email_fallback: Reminders::EmailFallback.available?,
        subscriptions: PushSubscription.order(created_at: :desc).map { |subscription| serialize(subscription) }
      }
    end

    # POST /api/push_subscriptions { subscription: PushSubscription.toJSON() }
    # Idempotent : un appareil qui se reabonne met a jour ses cles.
    def create
      data = params.require(:subscription)
      subscription = PushSubscription.find_or_initialize_by(endpoint: data[:endpoint])
      subscription.assign_attributes(
        p256dh: data.dig(:keys, :p256dh), auth: data.dig(:keys, :auth),
        user_agent: request.user_agent.to_s.truncate(250), last_error: nil
      )
      if subscription.save
        render json: serialize(subscription), status: :created
      else
        render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      PushSubscription.find(params[:id]).destroy
      head :no_content
    end

    # POST /api/push_subscriptions/test_notification : notification d'essai sur tous les appareils.
    def test_notification
      return render json: { errors: [PushNotifications::NOT_CONFIGURED] }, status: :service_unavailable unless PushNotifications.configured?

      reached = PushNotifications.broadcast(
        title: "Notification de test", body: "Les rappels arriveront ainsi, Monsieur.",
        url: "/reminders", tag: "reminder-test", badge_count: Reminder.due.count
      )
      render json: { reached: reached, total: PushSubscription.count }
    end

    private

    def serialize(subscription)
      subscription.as_json(only: %w[id endpoint created_at last_success_at last_failure_at last_error])
                  .merge("device" => subscription.device_label)
    end
  end
end
