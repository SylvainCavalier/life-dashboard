# Two kinds of accounts. The owner's, created by `rails owner:bootstrap` (or the
# development seed), sees the whole dashboard. Friends' accounts, created by
# `rails friends:create`, only reach the tools opened to them (Outils, Downloader,
# Transfert) and only their own records there. There is deliberately no
# :registerable module (no public sign-up) and no :recoverable module (no
# password-reset mailer is configured in production; reset with
# `rails owner:reset_password` / `friends:reset_password` instead).
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
#  role                 :string           default("friend"), not null
#  sign_in_count        :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#  index_users_on_role   (role)
#
class User < ApplicationRecord
  devise :database_authenticatable, :rememberable, :validatable,
         :trackable, :lockable

  ROLES = %w[owner friend].freeze

  # Donnees des outils ouverts aux amis : chaque compte a les siennes.
  has_many :video_folders, dependent: :destroy
  has_many :video_downloads, dependent: :destroy
  has_many :video_transcripts, dependent: :destroy
  has_many :file_transfers, dependent: :destroy

  validates :role, inclusion: { in: ROLES }

  scope :owners, -> { where(role: "owner") }
  scope :friends, -> { where(role: "friend") }

  ROLES.each do |value|
    define_method("#{value}?") { role == value }
  end

  # Le proprietaire du dashboard : celui a qui reviennent les enregistrements crees
  # hors session (rake tasks, Alfred, skills locales).
  def self.owner
    owners.order(:id).first
  end

  # Identifiants de bootstrap : connus, volontairement simples, et destines a
  # etre remplaces des la premiere connexion (must_change_password). Le mot de
  # passe ne passe pas les validations Devise (13 caracteres minimum), ce qui
  # est assume : la contrainte s'applique aux mots de passe que l'utilisateur
  # choisit, pas a celui qui sert uniquement a ouvrir la porte une fois.
  BOOTSTRAP_EMAIL = "sylv.cavalier@gmail.com".freeze
  BOOTSTRAP_PASSWORD = ENV.fetch("OWNER_PASSWORD", "password!").freeze

  def self.bootstrap!(email: BOOTSTRAP_EMAIL, password: BOOTSTRAP_PASSWORD)
    user = new(email: email, role: "owner", must_change_password: true)
    user.password = password
    user.save!(validate: false)
    user
  end

  # Compte d'ami. Sans mot de passe fourni : provisoire et aleatoire, a remplacer a la
  # premiere connexion. Avec : celui choisi par le proprietaire, garde tel quel.
  def self.create_friend!(email:, password: nil)
    provisional = password.blank?
    password = SecureRandom.alphanumeric(20) if provisional
    user = create!(email: email, role: "friend", password: password, must_change_password: provisional)
    [user, password]
  end
end
