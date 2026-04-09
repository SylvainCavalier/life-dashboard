class CreateLanguageSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :language_sessions do |t|
      t.references :language, null: false, foreign_key: true
      t.date :practiced_on, null: false
      t.string :source, default: "manual"
      t.text :notes

      t.timestamps
    end
  end
end
