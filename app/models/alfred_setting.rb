# Reglages d'Alfred modifiables a chaud depuis le chat (ligne unique).
class AlfredSetting < ApplicationRecord
  def self.instance
    first_or_create!
  end
end
