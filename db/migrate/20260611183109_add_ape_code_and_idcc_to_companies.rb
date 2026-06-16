class AddApeCodeAndIdccToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :ape_code, :string
    add_column :companies, :idcc, :string
  end
end
