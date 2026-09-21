class CreateSentinelWeeks < ActiveRecord::Migration[8.0]
  def change
    create_table :sentinel_weeks do |t|
      t.string :domain, null: false
      # A week is identified by its Monday and always spans Monday..Sunday.
      t.date :monday, null: false

      # State of the pipeline run (collect -> summarize -> digest). The table is
      # the source of truth: the UI polls it, it never looks at GoodJob.
      t.string :status, null: false, default: "pending"
      t.string :step
      t.integer :progress_done, null: false, default: 0
      t.integer :progress_total, null: false, default: 0
      t.text :error
      # Non-blocking problems of the last run (a source that failed, a scraper returning nothing...).
      t.jsonb :warnings, null: false, default: []
      t.datetime :requested_at
      t.datetime :started_at
      t.datetime :finished_at

      # Weekly digest, mirrors Sentinel::DigestSchema.
      t.jsonb :digest, null: false, default: {}
      t.string :digest_model
      t.datetime :digest_generated_at

      t.timestamps
    end

    add_index :sentinel_weeks, [:domain, :monday], unique: true
  end
end
