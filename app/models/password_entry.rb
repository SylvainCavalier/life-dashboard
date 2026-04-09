class PasswordEntry < ApplicationRecord
  encrypts :password

  validates :name, presence: true
  validates :login, presence: true
  validates :password, presence: true
end
