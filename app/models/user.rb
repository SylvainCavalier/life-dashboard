# Single-user application: the only account is the owner's, created by
# `rails owner:bootstrap` (or the development seed). There is deliberately no
# :registerable module (no public sign-up) and no :recoverable module (no
# password-reset mailer is configured in production; reset with
# `rails owner:reset_password` instead).
# == Schema Information
#
# Table name: users
#
#  id                   :bigint           not null, primary key
#  current_sign_in_at   :datetime
#  current_sign_in_ip   :string
#  email                :string           default(""), not null
#  encrypted_password   :string           default(""), not null
#  failed_attempts      :integer          default(0), not null
#  last_sign_in_at      :datetime
#  last_sign_in_ip      :string
#  locked_at            :datetime
#  must_change_password :boolean          default(FALSE), not null
#  remember_created_at  :datetime
#  sign_in_count        :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :validatable,
         :trackable, :lockable

  # Identifiants de bootstrap : connus, volontairement simples, et destines a
  # etre remplaces des la premiere connexion (must_change_password). Le mot de
  # passe ne passe pas les validations Devise (14 caracteres minimum), ce qui
  # est assume : la contrainte s'applique aux mots de passe que l'utilisateur
  # choisit, pas a celui qui sert uniquement a ouvrir la porte une fois.
  BOOTSTRAP_EMAIL = "sylv.cavalier@gmail.com".freeze
  BOOTSTRAP_PASSWORD = ENV.fetch("OWNER_PASSWORD", "password!").freeze

  def self.bootstrap!(email: BOOTSTRAP_EMAIL, password: BOOTSTRAP_PASSWORD)
    user = new(email: email, must_change_password: true)
    user.password = password
    user.save!(validate: false)
    user
  end
end
