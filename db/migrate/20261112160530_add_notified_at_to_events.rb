class AddNotifiedAtToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :notified_at, :datetime
  end
end
