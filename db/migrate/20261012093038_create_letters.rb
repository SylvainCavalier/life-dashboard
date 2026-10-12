class CreateLetters < ActiveRecord::Migration[8.0]
  def change
    create_table :letters do |t|
      t.text :sender
      t.text :recipient
      t.string :place
      t.date :letter_date
      t.string :mention
      t.string :reference
      t.string :subject
      # Document Tiptap (ProseMirror JSON), source du contenu de la lettre
      t.jsonb :body, null: false, default: {}
      t.string :signatory
      t.boolean :include_signature, null: false, default: true
      t.text :footer
      # Dernier PDF range dans la bibliotheque de documents (remplace a chaque envoi)
      t.references :document, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
  end
end
