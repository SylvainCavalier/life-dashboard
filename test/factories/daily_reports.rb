# == Schema Information
#
# Table name: daily_reports
#
#  id            :bigint           not null, primary key
#  content       :text
#  error         :text
#  finished_at   :datetime
#  input_tokens  :integer
#  model         :string
#  notified_at   :datetime
#  output_tokens :integer
#  read_at       :datetime
#  report_date   :date             not null
#  requested_at  :datetime
#  snapshot      :text
#  status        :string           default("pending"), not null
#  step          :string
#  weekend       :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_daily_reports_on_report_date  (report_date) UNIQUE
#
FactoryBot.define do
  factory :daily_report do
    report_date { Date.current }
    status { "pending" }

    trait :done do
      status { "done" }
      finished_at { Time.current }
      model { "claude-test" }
      snapshot do
        { "date" => report_date.iso8601, "weekend" => false, "sections" => {}, "warnings" => [],
          "refs" => { "Task#1" => { "label" => "Payer les charges", "path" => "/" },
                      "Mail#abc" => { "label" => "Bail (Agence)", "url" => "https://mail.google.com/mail/u/0/#all/abc" } } }
      end
      content do
        { "headline" => "Une journee chargee.", "opening" => "Bonjour Monsieur.", "closing" => "Bonne journee.",
          "today" => [], "people" => [], "money" => [], "remarks" => [],
          "mails" => [{ "title" => "Repondre a l'agence", "detail" => "Le bail attend.", "urgent" => true, "refs" => ["Mail#abc"] }],
          "priorities" => [{ "title" => "Charges", "detail" => "A payer.", "urgent" => false, "refs" => ["Task#1"] }] }
      end
    end
  end
end
