class CreatePushSubscriptions < ActiveRecord::Migration[8.0]
  def change
    # Un abonnement Web Push par appareil (iPhone, Mac...). Les cles sont celles
    # que le navigateur fournit : elles chiffrent le contenu de la notification.
    create_table :push_subscriptions do |t|
      t.text :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :user_agent
      t.datetime :last_success_at
      t.datetime :last_failure_at
      t.string :last_error

      t.timestamps
    end

    add_index :push_subscriptions, :endpoint, unique: true
  end
end
