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
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "owner#{n}@example.test" }
    password { "correct-horse-battery-staple" }
    role { "owner" }

    trait :friend do
      sequence(:email) { |n| "friend#{n}@example.test" }
      role { "friend" }
    end
  end
end
