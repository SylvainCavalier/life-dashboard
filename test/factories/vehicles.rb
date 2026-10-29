# == Schema Information
#
# Table name: vehicles
#
#  id                          :bigint           not null, primary key
#  brand                       :string
#  color                       :string
#  engine_displacement         :integer
#  first_registration_on       :date
#  fiscal_power                :integer
#  fuel                        :string
#  mileage                     :integer
#  mileage_on                  :date
#  model                       :string
#  name                        :string           not null
#  notes                       :text
#  oil_type                    :string
#  power_hp                    :integer
#  purchase_mileage            :integer
#  purchase_price              :decimal(10, 2)
#  purchased_on                :date
#  registration_number         :string
#  sale_price                  :decimal(10, 2)
#  service_interval_km         :integer
#  service_interval_months     :integer
#  sold_on                     :date
#  status                      :string           default("active"), not null
#  technical_inspection_due_on :date
#  tire_size                   :string
#  vehicle_type                :string           default("voiture"), not null
#  version                     :string
#  vin                         :string
#  year                        :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
FactoryBot.define do
  factory :vehicle do
    name { "Clio" }
    vehicle_type { "voiture" }
    status { "active" }
    brand { "Renault" }
    model { "Clio V" }
    registration_number { "AB-123-CD" }
  end

  factory :vehicle_intervention do
    vehicle
    occurred_on { Date.new(2026, 3, 10) }
    kind { "entretien" }
    title { "Révision des 60 000 km" }
    mileage { 60_000 }
    cost { 289 }
    garage { "Garage du Centre" }
  end
end
