class AddRcsToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :rcs, :string
  end
end
