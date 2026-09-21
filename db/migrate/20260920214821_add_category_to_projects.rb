class AddCategoryToProjects < ActiveRecord::Migration[8.0]
  def change
    # Les projets existants sont tous des projets de developpement web.
    add_column :projects, :category, :string, default: "developpement", null: false
    add_index :projects, :category
  end
end
