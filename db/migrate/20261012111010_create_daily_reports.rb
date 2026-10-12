class CreateDailyReports < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_reports do |t|
      t.date :report_date, null: false
      t.boolean :weekend, null: false, default: false
      t.string :status, null: false, default: "pending"
      t.string :step
      # Chiffres (encrypts) : extraits de mails, numeros, adresses.
      t.text :snapshot
      t.text :content
      t.text :error
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.datetime :requested_at
      t.datetime :finished_at
      t.datetime :notified_at
      t.datetime :read_at

      t.timestamps
    end
    add_index :daily_reports, :report_date, unique: true
  end
end
