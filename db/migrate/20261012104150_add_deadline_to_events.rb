class AddDeadlineToEvents < ActiveRecord::Migration[8.0]
  def change
    add_reference :events, :deadline, foreign_key: { on_delete: :nullify }, null: true
  end
end
