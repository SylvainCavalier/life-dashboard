class AddVehicleToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_reference :documents, :vehicle, foreign_key: { on_delete: :nullify }
  end
end
