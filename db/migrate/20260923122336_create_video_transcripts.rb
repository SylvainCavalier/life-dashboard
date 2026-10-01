class CreateVideoTranscripts < ActiveRecord::Migration[8.0]
  def change
    create_table :video_transcripts do |t|
      t.string :title, null: false
      t.string :language, null: false, default: "auto"
      t.string :status, null: false, default: "pending"
      t.string :step
      # Reference de la video (citation du Downloader) figee a la creation : elle survit
      # a la suppression du telechargement et figure en tete du PDF.
      t.text :source_citation
      t.text :error
      t.integer :duration_seconds
      # Pose quand Voxtral a repondu : une video sans parole a une transcription vide
      # mais ne doit pas etre retranscrite a la relance.
      t.datetime :transcribed_at
      t.jsonb :transcript, null: false, default: []
      t.jsonb :speaker_names, null: false, default: {}
      t.jsonb :summary, null: false, default: {}
      t.string :summary_model
      t.datetime :requested_at
      t.datetime :finished_at
      t.references :video_download, foreign_key: { on_delete: :nullify }
      t.references :document, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    add_index :video_transcripts, :created_at
  end
end
