class MailAccount < ApplicationRecord
  PROVIDERS = %w[gmail zoho orange microsoft yahoo protonmail other].freeze

  PROVIDER_URLS = {
    "gmail" => "https://mail.google.com",
    "zoho" => "https://mail.zoho.eu",
    "orange" => "https://messagerie.orange.fr",
    "microsoft" => "https://outlook.live.com",
    "yahoo" => "https://mail.yahoo.com",
    "protonmail" => "https://mail.proton.me"
  }.freeze

  PROVIDER_DEFAULTS = {
    "gmail" => { imap_server: "imap.gmail.com", imap_port: 993, smtp_server: "smtp.gmail.com", smtp_port: 587 },
    "zoho" => { imap_server: "imap.zoho.eu", imap_port: 993, smtp_server: "smtp.zoho.eu", smtp_port: 587 },
    "orange" => { imap_server: "imap.orange.fr", imap_port: 993, smtp_server: "smtp.orange.fr", smtp_port: 465 },
    "microsoft" => { imap_server: "outlook.office365.com", imap_port: 993, smtp_server: "smtp.office365.com", smtp_port: 587 },
    "yahoo" => { imap_server: "imap.mail.yahoo.com", imap_port: 993, smtp_server: "smtp.mail.yahoo.com", smtp_port: 587 },
    "protonmail" => { imap_server: "127.0.0.1", imap_port: 1143, smtp_server: "127.0.0.1", smtp_port: 1025 }
  }.freeze

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider_url, presence: true

  scope :ordered, -> { order(created_at: :desc) }
end
