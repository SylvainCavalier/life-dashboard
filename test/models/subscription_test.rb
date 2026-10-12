# == Schema Information
#
# Table name: subscriptions
#
#  id            :bigint           not null, primary key
#  billing_cycle :string           default("monthly"), not null
#  category      :string
#  cost          :decimal(8, 2)    not null
#  end_date      :date
#  name          :string           not null
#  start_date    :date
#  url           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  def subscription(**attrs)
    Subscription.new(name: "Abonnement", cost: 10, billing_cycle: "monthly", **attrs)
  end

  test "prochain renouvellement mensuel, depuis la date de debut" do
    today = Date.new(2026, 10, 12)

    assert_equal Date.new(2026, 10, 14), subscription(start_date: Date.new(2024, 9, 14)).next_renewal_on(today)
    assert_equal today, subscription(start_date: Date.new(2025, 1, 12)).next_renewal_on(today)
    assert_equal Date.new(2026, 11, 3), subscription(start_date: Date.new(2026, 1, 3)).next_renewal_on(today)
    # Un debut a venir est le premier prelevement.
    assert_equal Date.new(2026, 12, 1), subscription(start_date: Date.new(2026, 12, 1)).next_renewal_on(today)
  end

  test "un debut le 31 tombe en fin de mois puis revient au 31" do
    sub = subscription(start_date: Date.new(2026, 1, 31))

    assert_equal Date.new(2026, 2, 28), sub.next_renewal_on(Date.new(2026, 2, 10))
    assert_equal Date.new(2026, 3, 31), sub.next_renewal_on(Date.new(2026, 3, 1))
  end

  test "renouvellement annuel, et aucun sans date de debut ou apres la fin" do
    today = Date.new(2026, 10, 12)

    assert_equal Date.new(2027, 1, 8), subscription(billing_cycle: "yearly", start_date: Date.new(2025, 1, 8)).next_renewal_on(today)
    assert_nil subscription.next_renewal_on(today)
    assert_nil subscription(start_date: Date.new(2025, 1, 20), end_date: Date.new(2026, 10, 15)).next_renewal_on(today)
  end
end
