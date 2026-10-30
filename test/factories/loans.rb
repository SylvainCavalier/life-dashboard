# == Schema Information
#
# Table name: loans
#
#  id            :bigint           not null, primary key
#  amount        :decimal(10, 2)
#  direction     :string           not null
#  due_on        :date
#  item          :string
#  kind          :string           default("object"), not null
#  notes         :text
#  person_name   :string           not null
#  repaid_amount :decimal(10, 2)
#  returned_on   :date
#  started_on    :date             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  contact_id    :bigint
#
# Indexes
#
#  index_loans_on_contact_id   (contact_id)
#  index_loans_on_returned_on  (returned_on)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#
FactoryBot.define do
  factory :loan do
    direction { "lent" }
    kind { "object" }
    person_name { "Paul" }
    item { "Perceuse" }
    started_on { Date.new(2026, 9, 1) }
  end
end
