# Reglages d'Alfred modifiables a chaud depuis le chat (ligne unique).
# == Schema Information
#
# Table name: alfred_settings
#
#  id                  :bigint           not null, primary key
#  custom_instructions :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class AlfredSetting < ApplicationRecord
  def self.instance
    first_or_create!
  end
end
