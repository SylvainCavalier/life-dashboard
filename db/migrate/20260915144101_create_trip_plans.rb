class CreateTripPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :trip_plans do |t|
      # One AI report per trip, regenerated in place.
      t.references :trip, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "pending"
      # Structured report produced by the OpenAI structured output schema
      # (Trips::TripPlanSchema). Read and written as a whole, never queried.
      t.jsonb :content, null: false, default: {}
      t.string :model
      t.text :error
      t.datetime :requested_at
      t.datetime :started_at
      t.datetime :generated_at
      t.decimal :estimated_total_eur, precision: 10, scale: 2
      # Fingerprint of the trip attributes used for the report, to flag it
      # as outdated when the trip changes afterwards.
      t.string :input_fingerprint

      t.timestamps
    end
  end
end
