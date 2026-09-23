# Reglages d'Alfred modifiables a chaud depuis la page Alfred (ligne unique).
# `prompt_overrides` remplace section par section le prompt par defaut du code
# (Alfred::Prompt::SECTIONS) ; `custom_instructions` s'ajoute a la fin.
# == Schema Information
#
# Table name: alfred_settings
#
#  id                  :bigint           not null, primary key
#  custom_instructions :text
#  prompt_overrides    :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class AlfredSetting < ApplicationRecord
  validate :prompt_overrides_known

  def self.instance
    first_or_create!
  end

  # Texte surcharge d'une section, nil si elle garde son texte par defaut.
  def override_for(key)
    prompt_overrides[key.to_s].presence
  end

  # Pose ou retire (texte vide / nil) les surcharges passees, sans toucher aux autres.
  def merge_overrides!(changes)
    merged = prompt_overrides.dup
    changes.each do |key, text|
      text = text.to_s.strip
      text.empty? ? merged.delete(key.to_s) : merged[key.to_s] = text
    end
    update!(prompt_overrides: merged)
  end

  private

  def prompt_overrides_known
    unknown = prompt_overrides.keys - Alfred::Prompt::SECTIONS.map { |s| s[:key] }
    errors.add(:prompt_overrides, "sections inconnues : #{unknown.join(', ')}") if unknown.any?
  end
end
