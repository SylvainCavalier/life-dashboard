class RenameCompanyNameToTradeNameAndAddLegalRep < ActiveRecord::Migration[8.0]
  def change
    rename_column :companies, :name, :trade_name
    add_column :companies, :legal_representative_name, :string
  end
end
