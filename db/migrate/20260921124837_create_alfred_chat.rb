# Conversations avec Alfred, ecritures en attente de confirmation et reglages.
class CreateAlfredChat < ActiveRecord::Migration[8.0]
  def change
    create_table :alfred_conversations do |t|
      t.string   :title
      t.datetime :last_message_at
      t.timestamps
    end
    add_index :alfred_conversations, :last_message_at

    create_table :alfred_messages do |t|
      t.references :alfred_conversation, null: false, foreign_key: true
      t.string  :role, null: false                      # user | assistant | event
      t.string  :status, null: false, default: "done"   # pending | processing | done | failed
      t.text    :content                                # chiffre (peut citer un IBAN, un numero de passeport...)
      t.jsonb   :steps, null: false, default: []        # outils appeles, pour l'affichage de la progression
      t.jsonb   :sources, null: false, default: []      # passages du corpus remontes pendant le tour
      t.text    :error
      t.string  :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cached_tokens
      t.integer :latency_ms
      t.timestamps
    end

    # Une ecriture n'est jamais executee par le modele : il la propose, Sylvain la confirme.
    create_table :alfred_actions do |t|
      t.references :alfred_conversation, null: false, foreign_key: true
      t.references :alfred_message, foreign_key: true
      t.string   :operation, null: false                 # create | update
      t.string   :target_model, null: false
      t.bigint   :record_id
      t.text     :payload, null: false                   # JSON chiffre : { attributes:, before: }
      t.string   :summary
      t.string   :status, null: false, default: "proposed" # proposed | executed | cancelled | failed
      t.text     :error
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :alfred_actions, :status

    create_table :alfred_settings do |t|
      t.text :custom_instructions
      t.timestamps
    end
  end
end
