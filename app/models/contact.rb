class Contact < ApplicationRecord
  RELATIONSHIP_TYPES = %w[ami copine famille collegue connaissance client eleve medias autre].freeze

  validates :first_name, :last_name, presence: true
  validates :relationship_type, inclusion: { in: RELATIONSHIP_TYPES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :ordered, -> { order(:last_name, :first_name) }
end
