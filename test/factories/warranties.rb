# == Schema Information
#
# Table name: warranties
#
#  id              :bigint           not null, primary key
#  brand           :string
#  category        :string           default("autre"), not null
#  duration_months :integer
#  ends_on         :date             not null
#  model_reference :string
#  name            :string           not null
#  notes           :text
#  order_number    :string
#  price           :decimal(10, 2)
#  purchased_on    :date             not null
#  serial_number   :string
#  store           :string
#  support_contact :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_warranties_on_ends_on  (ends_on)
#
FactoryBot.define do
  factory :warranty do
    name { "Lave-linge" }
    brand { "Bosch" }
    category { "electromenager" }
    store { "Darty" }
    purchased_on { Date.new(2025, 3, 15) }
    duration_months { 24 }
    price { 549 }
  end
end
