class AddReplyingSinceToSmsCorrespondents < ActiveRecord::Migration[8.0]
  def change
    add_column :sms_correspondents, :replying_since, :datetime
  end
end
