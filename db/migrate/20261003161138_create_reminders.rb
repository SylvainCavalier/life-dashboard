class CreateReminders < ActiveRecord::Migration[8.0]
  def change
    create_table :reminders do |t|
      t.string :title, null: false
      t.text :notes
      # Prochaine echeance. Pour un rappel recurrent, elle avance a chaque occurrence.
      t.datetime :remind_at, null: false
      t.string :recurrence, null: false, default: "none"
      # Fiche du dashboard a laquelle le rappel se rapporte (contact, tache, projet...)
      t.references :remindable, polymorphic: true

      # Etat de l'occurrence en cours, remis a zero quand remind_at change
      t.integer :attempts, null: false, default: 0
      t.datetime :notified_at
      t.datetime :last_attempt_at
      t.datetime :acknowledged_at
      t.datetime :email_sent_at

      # Rappel ponctuel traite (un rappel recurrent n'est jamais termine, il avance)
      t.datetime :completed_at

      t.timestamps
    end

    add_index :reminders, :remind_at
    add_index :reminders, :completed_at
  end
end
