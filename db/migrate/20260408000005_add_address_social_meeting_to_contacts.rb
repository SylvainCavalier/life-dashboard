class AddAddressSocialMeetingToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :address, :string
    add_column :contacts, :met_through, :string
    add_column :contacts, :met_year, :integer
    add_column :contacts, :social_instagram, :string
    add_column :contacts, :social_linkedin, :string
    add_column :contacts, :social_twitter, :string
    add_column :contacts, :social_facebook, :string
    add_column :contacts, :social_tiktok, :string
    add_column :contacts, :social_snapchat, :string
    add_column :contacts, :social_youtube, :string
  end
end
