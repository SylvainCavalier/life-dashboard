class AddSmsWhitelistOpening < ActiveRecord::Migration[8.0]
  def change
    add_column :alfred_settings, :sms_open_until, :datetime
    add_column :sms_correspondents, :temporary, :boolean, null: false, default: false
  end
end
