# == Schema Information
#
# Table name: loans
#
#  id            :bigint           not null, primary key
#  amount        :decimal(10, 2)
#  direction     :string           not null
#  due_on        :date
#  item          :string
#  kind          :string           default("object"), not null
#  notes         :text
#  person_name   :string           not null
#  repaid_amount :decimal(10, 2)
#  returned_on   :date
#  started_on    :date             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  contact_id    :bigint
#
# Indexes
#
#  index_loans_on_contact_id   (contact_id)
#  index_loans_on_returned_on  (returned_on)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#

# Pret d'un objet ou d'argent (page Prets), dans un sens ou dans l'autre :
# `lent` = Sylvain a prete, `borrowed` = on lui a prete. La personne est un contact
# du dashboard ou un simple nom ; `person_name` est toujours rempli (repris du contact),
# pour que le pret garde son nom si le contact est supprime (cle etrangere en nullify).
# Un pret est en cours tant que `returned_on` est vide. Pour de l'argent, `repaid_amount`
# suit les remboursements partiels ; rembourse en entier, le pret se clot de lui-meme.
class Loan < ApplicationRecord
  DIRECTIONS = %w[lent borrowed].freeze
  KINDS = %w[object money].freeze

  # Retour prevu dans ce delai : signale sur la page et dans le rapport du matin.
  DUE_SOON_DAYS = 7

  belongs_to :contact, optional: true

  before_validation :fill_person_name
  before_validation :close_when_repaid

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :kind, inclusion: { in: KINDS }
  validates :person_name, presence: { message: "requise (un contact ou un nom)" }
  validates :started_on, presence: true
  validates :item, presence: { message: "requis : quel objet ?" }, if: :object?
  validates :amount, presence: { message: "requis pour un pret d'argent" }, if: :money?
  validates :amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :repaid_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :repaid_within_amount
  validate :dates_after_start

  scope :ordered, -> { order(Arel.sql("returned_on IS NOT NULL"), returned_on: :desc, started_on: :desc, id: :desc) }
  scope :outstanding, -> { where(returned_on: nil) }

  def object? = kind == "object"
  def money? = kind == "money"
  def returned? = returned_on.present?

  # « Perceuse », « 200,00 € (loyer de mars) »
  def label
    return item.to_s unless money?

    [ActiveSupport::NumberHelper.number_to_currency(amount, unit: "€", format: "%n %u", separator: ",", delimiter: " "),
     item.presence && "(#{item})"].compact.join(" ")
  end

  def remaining_amount
    return unless money? && amount

    [amount - repaid_amount.to_d, 0].max
  end

  def days_until_due(today = Date.current)
    (due_on - today).to_i if due_on && !returned?
  end

  # returned | overdue (retour prevu depasse) | due_soon (sous DUE_SOON_DAYS jours) | ongoing
  def status(today = Date.current)
    return "returned" if returned?

    days = days_until_due(today)
    return "ongoing" if days.nil?
    return "overdue" if days.negative?

    days <= DUE_SOON_DAYS ? "due_soon" : "ongoing"
  end

  def api_attributes
    attributes.symbolize_keys.merge(
      label: label,
      status: status,
      days_until_due: days_until_due,
      remaining_amount: remaining_amount,
      contact: contact && { id: contact.id, name: contact_name(contact) }
    )
  end

  private

  def contact_name(contact)
    [contact.first_name, contact.last_name].compact_blank.join(" ")
  end

  # Le nom suit le contact choisi ; sans contact, le nom saisi reste.
  def fill_person_name
    self.person_name = contact_name(contact) if contact && (person_name.blank? || will_save_change_to_contact_id?)
  end

  def close_when_repaid
    return unless money? && !returned? && amount && repaid_amount && repaid_amount >= amount

    self.returned_on = Date.current
  end

  def repaid_within_amount
    return unless amount && repaid_amount && repaid_amount > amount

    errors.add(:repaid_amount, "ne peut pas depasser le montant prete")
  end

  def dates_after_start
    return unless started_on

    errors.add(:due_on, "doit etre posterieure au debut du pret") if due_on && due_on < started_on
    errors.add(:returned_on, "doit etre posterieure au debut du pret") if returned_on && returned_on < started_on
  end
end
