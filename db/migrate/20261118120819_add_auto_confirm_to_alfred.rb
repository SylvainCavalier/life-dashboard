class AddAutoConfirmToAlfred < ActiveRecord::Migration[8.0]
  def change
    # Actions dispensees de confirmation dans le chat (cles "Modele:operation", Alfred::AutoConfirm).
    add_column :alfred_settings, :auto_confirm, :jsonb, null: false, default: []
    # Action executee sans carte a confirmer, en vertu de ce reglage.
    add_column :alfred_actions, :auto_confirmed, :boolean, null: false, default: false
  end
end
