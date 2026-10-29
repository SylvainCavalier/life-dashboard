class AddVehicleToInsuredItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :insured_items, :vehicle, foreign_key: { on_delete: :nullify }
  end
end
