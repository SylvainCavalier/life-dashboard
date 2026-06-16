# == Schema Information
#
# Table name: clients
#
#  id            :bigint           not null, primary key
#  address_line1 :string
#  address_line2 :string
#  city          :string
#  country       :string
#  email         :string
#  name          :string
#  notes         :text
#  phone         :string
#  postal_code   :string
#  siret         :string
#  vat_number    :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  company_id    :bigint           not null
#
# Indexes
#
#  index_clients_on_company_id  (company_id)
#
# Foreign Keys
#
#  fk_rails_...  (company_id => companies.id)
#
FactoryBot.define do
  factory :client do
    company { nil }
    name { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    siret { "MyString" }
    vat_number { "MyString" }
    address_line1 { "MyString" }
    address_line2 { "MyString" }
    postal_code { "MyString" }
    city { "MyString" }
    country { "MyString" }
    notes { "MyText" }
  end
end
