class CreateMeetings < ActiveRecord::Migration[8.0]
  def change
    create_table :meetings do |t|
      t.string :title, null: false
      t.string :kind, null: false, default: "in_person"
      t.datetime :held_at, null: false
      t.text :participants
      t.text :context
      t.string :status, null: false, default: "pending"
      t.string :step
      t.text :error
      t.integer :duration_seconds
      t.jsonb :transcript, null: false, default: []
      t.jsonb :speaker_names, null: false, default: {}
      t.jsonb :summary, null: false, default: {}
      t.string :summary_model
      t.datetime :requested_at
      t.datetime :finished_at
      # Le PDF produit (transcription + synthese) : supprimer le document ne supprime pas la reunion.
      t.references :document, null: true, foreign_key: { on_delete: :nullify }

      t.timestamps
    end
    add_index :meetings, :held_at
  end
end
