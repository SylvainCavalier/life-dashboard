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
class Subscription < ApplicationRecord
  BILLING_CYCLES = %w[monthly yearly].freeze
  CATEGORIES = %w[ia sport telecom streaming assurance logiciel media alimentation autre].freeze

  validates :name, presence: true
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :billing_cycle, presence: true, inclusion: { in: BILLING_CYCLES }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(end_date: nil).or(where(end_date: Date.current..)) }

  # Prochain prelevement (aujourd'hui compris), deduit de start_date et du cycle : la
  # date anniversaire tous les mois ou tous les ans, calculee depuis start_date et non
  # depuis la precedente (un debut le 31 tombe le 28 fevrier puis de nouveau le 31 mars).
  # nil sans date de debut, ou si l'abonnement prend fin avant.
  def next_renewal_on(today = Date.current)
    return nil if start_date.nil?

    step = billing_cycle == "yearly" ? 12 : 1
    elapsed = ((today.year * 12) + today.month) - ((start_date.year * 12) + start_date.month)
    index = [(elapsed / step) - 1, 0].max
    index += 1 while start_date >> (step * index) < today
    date = start_date >> (step * index)
    date unless end_date && date > end_date
  end

  def as_json(options = {})
    super.merge("next_renewal_on" => next_renewal_on)
  end
end
