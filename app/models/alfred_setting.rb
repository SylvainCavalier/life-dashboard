# Reglages d'Alfred modifiables a chaud depuis la page Alfred (ligne unique).
# `prompt_overrides` remplace section par section le prompt par defaut du code
# (Alfred::Prompt::SECTIONS) ; `custom_instructions` s'ajoute a la fin.
# `suggestions` : phrases proposees a l'ouverture d'une conversation vide dans le
# widget ; tableau vide = phrases par defaut (DEFAULT_SUGGESTIONS).
# == Schema Information
#
# Table name: alfred_settings
#
#  id                  :bigint           not null, primary key
#  custom_instructions :text
#  prompt_overrides    :jsonb            not null
#  suggestions         :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class AlfredSetting < ApplicationRecord
  DEFAULT_SUGGESTIONS = [
    "Quels sont mes rendez-vous de la semaine ?",
    "Retrouve mon dernier avis d'imposition.",
    "Ajoute une tâche : renouveler mon passeport."
  ].freeze
  MAX_SUGGESTIONS = 5
  MAX_SUGGESTION_LENGTH = 200

  validate :prompt_overrides_known
  validate :suggestions_well_formed

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

  # Phrases affichees par le widget : celles de Sylvain, sinon celles du code.
  def effective_suggestions
    suggestions.presence || DEFAULT_SUGGESTIONS
  end

  # Nettoie la liste (espaces, lignes vides, doublons). Une liste identique aux
  # phrases par defaut n'est pas stockee, pour suivre le code si elles changent.
  def replace_suggestions!(list)
    cleaned = Array(list).map { |text| text.to_s.strip }.reject(&:empty?).uniq
    update!(suggestions: cleaned == DEFAULT_SUGGESTIONS ? [] : cleaned)
  end

  private

  def prompt_overrides_known
    unknown = prompt_overrides.keys - Alfred::Prompt::SECTIONS.map { |s| s[:key] }
    errors.add(:prompt_overrides, "sections inconnues : #{unknown.join(', ')}") if unknown.any?
  end

  def suggestions_well_formed
    return errors.add(:suggestions, "doit etre une liste") unless suggestions.is_a?(Array)

    errors.add(:suggestions, "#{MAX_SUGGESTIONS} au maximum") if suggestions.size > MAX_SUGGESTIONS
    return unless suggestions.any? { |text| !text.is_a?(String) || text.length > MAX_SUGGESTION_LENGTH }

    errors.add(:suggestions, "chaque suggestion est un texte de #{MAX_SUGGESTION_LENGTH} caracteres au plus")
  end
end
