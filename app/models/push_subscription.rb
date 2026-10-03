# == Schema Information
#
# Table name: push_subscriptions
#
#  id              :bigint           not null, primary key
#  auth            :string           not null
#  endpoint        :text             not null
#  last_error      :string
#  last_failure_at :datetime
#  last_success_at :datetime
#  p256dh          :string           not null
#  user_agent      :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_push_subscriptions_on_endpoint  (endpoint) UNIQUE
#
# Abonnement Web Push d'un appareil (voir PushNotifications). Cree quand Sylvain
# active les notifications depuis la page Rappels ; supprime automatiquement
# quand le service push le declare expire (application retiree de l'ecran
# d'accueil, notifications desactivees dans les reglages).
class PushSubscription < ApplicationRecord
  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh, :auth, presence: true

  # Nom lisible de l'appareil, deduit du user agent au moment de l'abonnement.
  def device_label
    ua = user_agent.to_s
    device =
      if ua.include?("iPhone") then "iPhone"
      elsif ua.include?("iPad") then "iPad"
      elsif ua.include?("Android") then "Android"
      elsif ua.include?("Macintosh") then "Mac"
      elsif ua.include?("Windows") then "Windows"
      else "Appareil inconnu"
      end
    browser =
      if ua.match?(/Edg\//) then "Edge"
      elsif ua.match?(/Firefox\//) then "Firefox"
      elsif ua.match?(/Chrome\//) then "Chrome"
      elsif ua.match?(/Safari\//) then "Safari"
      end
    [device, browser].compact.join(" · ")
  end
end
