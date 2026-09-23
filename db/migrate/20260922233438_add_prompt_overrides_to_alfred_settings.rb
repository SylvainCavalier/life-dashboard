class AddPromptOverridesToAlfredSettings < ActiveRecord::Migration[8.0]
  def change
    # Sections du prompt systeme reecrites depuis la page Alfred : { "tone" => "texte", ... }.
    # Une section absente garde le texte par defaut du code (Alfred::Prompt::SECTIONS).
    add_column :alfred_settings, :prompt_overrides, :jsonb, default: {}, null: false
  end
end
