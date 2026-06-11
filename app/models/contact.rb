# == Schema Information
#
# Table name: contacts
#
#  id                :bigint           not null, primary key
#  address           :string
#  birth_date        :date
#  city              :string
#  dislikes          :text
#  email             :string
#  first_name        :string           not null
#  followed          :boolean          default(FALSE), not null
#  gender            :string
#  last_contacted_on :date
#  last_name         :string           not null
#  likes             :text
#  loans             :text
#  met_through       :string
#  met_year          :integer
#  notes             :text
#  occupation        :string
#  phone             :string
#  relationship_type :string           default("connaissance"), not null
#  social_facebook   :string
#  social_instagram  :string
#  social_linkedin   :string
#  social_snapchat   :string
#  social_tiktok     :string
#  social_twitter    :string
#  social_youtube    :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_contacts_on_last_name_and_first_name  (last_name,first_name)
#  index_contacts_on_relationship_type         (relationship_type)
#
class Contact < ApplicationRecord
  RELATIONSHIP_TYPES = %w[ami copine famille collegue connaissance client eleve medias autre].freeze

  validates :first_name, :last_name, presence: true
  validates :relationship_type, inclusion: { in: RELATIONSHIP_TYPES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :ordered, -> { order(:last_name, :first_name) }
end
