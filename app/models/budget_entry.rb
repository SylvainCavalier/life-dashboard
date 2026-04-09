class BudgetEntry < ApplicationRecord
  ENTRY_TYPES = %w[income expense].freeze
  RECURRENCES = %w[fixed variable].freeze
  CATEGORIES = %w[
    salaire freelance loyer_percu investissement autre_revenu
    loyer credit assurance abonnement impot taxe_fonciere charge
    transport sante education autre_depense
  ].freeze

  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
  validates :recurrence, presence: true, inclusion: { in: RECURRENCES }
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :month, inclusion: { in: 1..12 }, allow_nil: true
  validates :year, numericality: { only_integer: true, greater_than: 2000 }, allow_nil: true

  validate :variable_entries_require_month_and_year

  scope :ordered, -> { order(:name) }
  scope :fixed, -> { where(recurrence: 'fixed') }
  scope :variable, -> { where(recurrence: 'variable') }
  scope :incomes, -> { where(entry_type: 'income') }
  scope :expenses, -> { where(entry_type: 'expense') }
  scope :for_month, ->(month, year) { where(month: month, year: year) }

  private

  def variable_entries_require_month_and_year
    if recurrence == 'variable' && (month.blank? || year.blank?)
      errors.add(:base, "Les entrées variables nécessitent un mois et une année")
    end
  end
end
