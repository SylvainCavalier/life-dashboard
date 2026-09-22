# == Schema Information
#
# Table name: events
#
#  id                :bigint           not null, primary key
#  all_day           :boolean          default(FALSE)
#  color             :string           default("#6366f1")
#  description       :text
#  end_time          :datetime
#  event_type        :string           default("autre"), not null
#  google_updated_at :datetime
#  location          :string
#  reminder_minutes  :integer          default(60)
#  start_time        :datetime         not null
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  google_event_id   :string
#
# Indexes
#
#  index_events_on_event_type       (event_type)
#  index_events_on_google_event_id  (google_event_id) UNIQUE
#  index_events_on_start_time       (start_time)
#
FactoryBot.define do
  factory :event do
    title { "Rendez-vous test" }
    event_type { "rdv" }
    start_time { Time.zone.local(2026, 9, 22, 9, 0) }
    end_time { Time.zone.local(2026, 9, 22, 10, 0) }
    location { "Cabinet" }
  end
end
