# == Schema Information
#
# Table name: reminders
#
#  id              :bigint           not null, primary key
#  acknowledged_at :datetime
#  attempts        :integer          default(0), not null
#  completed_at    :datetime
#  email_sent_at   :datetime
#  last_attempt_at :datetime
#  notes           :text
#  notified_at     :datetime
#  recurrence      :string           default("none"), not null
#  remind_at       :datetime         not null
#  remindable_type :string
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  remindable_id   :bigint
#
# Indexes
#
#  index_reminders_on_completed_at  (completed_at)
#  index_reminders_on_remind_at     (remind_at)
#  index_reminders_on_remindable    (remindable_type,remindable_id)
#
FactoryBot.define do
  factory :reminder do
    title { "Appeler le notaire" }
    remind_at { 1.hour.from_now }
    recurrence { "none" }
  end

  factory :push_subscription do
    sequence(:endpoint) { |n| "https://web.push.apple.com/abonnement-#{n}" }
    p256dh { "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM" }
    auth { "tBHItJI5svbpez7KI4CCXg" }
    user_agent { "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1" }
  end
end
