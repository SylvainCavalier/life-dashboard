# == Schema Information
#
# Table name: crm_profiles
#
#  id                  :bigint           not null, primary key
#  last_contact_method :string
#  last_contact_on     :date
#  next_appointment_on :date
#  notes               :text
#  priority            :string           default("moyenne"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  contact_id          :bigint           not null
#
# Indexes
#
#  index_crm_profiles_on_contact_id  (contact_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#
class CrmProfile < ApplicationRecord
  PRIORITIES = %w[basse moyenne haute].freeze
  CONTACT_METHODS = %w[telephone email sms visio rencontre autre].freeze

  belongs_to :contact

  validates :priority, inclusion: { in: PRIORITIES }
  validates :last_contact_method, inclusion: { in: CONTACT_METHODS }, allow_blank: true
  validates :contact_id, uniqueness: true

  scope :due_or_overdue, -> { where(next_appointment_on: ..Date.current) }
  scope :ordered, -> { order(Arel.sql("next_appointment_on ASC NULLS LAST")) }
end
