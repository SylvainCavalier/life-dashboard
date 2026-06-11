# == Schema Information
#
# Table name: password_entries
#
#  id         :bigint           not null, primary key
#  login      :string           not null
#  name       :string           not null
#  password   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class PasswordEntry < ApplicationRecord
  encrypts :password

  validates :name, presence: true
  validates :login, presence: true
  validates :password, presence: true
end
