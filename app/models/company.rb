class Company < ApplicationRecord
  has_many :quotes, dependent: :destroy
  has_many :invoices, dependent: :destroy

  LEGAL_FORMS = %w[sas sarl eurl sa sci sasu auto_entrepreneur association autre].freeze
  STATUSES = %w[active inactive en_creation radiee].freeze

  validates :name, presence: true
  validates :legal_form, inclusion: { in: LEGAL_FORMS }, allow_blank: true
  validates :status, inclusion: { in: STATUSES }, allow_blank: true
  validates :capital, :revenue, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :employees_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered, -> { order(created_at: :desc) }
end
