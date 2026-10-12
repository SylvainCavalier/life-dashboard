class AddWindowEnvelopeToLetters < ActiveRecord::Migration[8.0]
  def change
    # Faux = mise en page compacte (destinataire au niveau de l'expediteur) ;
    # vrai = destinataire dans la fenetre d'une enveloppe DL (Letters::Layout)
    add_column :letters, :window_envelope, :boolean, null: false, default: false
  end
end
