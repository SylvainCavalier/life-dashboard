# == Schema Information
#
# Table name: deadlines
#
#  id              :bigint           not null, primary key
#  amount          :decimal(10, 2)
#  category        :string           default("autre"), not null
#  due_on          :date             not null
#  ends_on         :date
#  generated_until :date
#  notes           :text
#  recurrence      :string           default("none"), not null
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_deadlines_on_due_on  (due_on)
#
FactoryBot.define do
  factory :deadline do
    title { "Taxe foncière" }
    category { "impots" }
    due_on { Date.new(2026, 10, 15) }
    recurrence { "yearly" }
    amount { 1240 }
  end
end
