class AddCategoryAndDomainToCvExperiences < ActiveRecord::Migration[8.0]
  def change
    add_column :cv_experiences, :category, :string
    add_column :cv_experiences, :domain, :string, array: true, default: []
  end
end
