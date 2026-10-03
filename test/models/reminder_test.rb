# == Schema Information
#
# Table name: reminders
#
#  id              :bigint           not null, primary key
#  acknowledged_at :datetime
#  attempts        :integer          default(0), not null
#  completed_at    :datetime
#  email_sent_at   :datetime
#  last_attempt_at :datetime
#  notes           :text
#  notified_at     :datetime
#  recurrence      :string           default("none"), not null
#  remind_at       :datetime         not null
#  remindable_type :string
#  title           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  remindable_id   :bigint
#
# Indexes
#
#  index_reminders_on_completed_at  (completed_at)
#  index_reminders_on_remind_at     (remind_at)
#  index_reminders_on_remindable    (remindable_type,remindable_id)
#
require "test_helper"

class ReminderTest < ActiveSupport::TestCase
  test "un rappel ne se cree pas dans le passe" do
    reminder = build(:reminder, remind_at: 1.hour.ago)
    assert_not reminder.valid?
    assert_includes reminder.errors.full_messages.join, "deja passee"
  end

  test "la fiche liee doit exister et faire partie des types autorises" do
    assert_not build(:reminder, remindable_type: "Task", remindable_id: 0).valid?
    assert_not build(:reminder, remindable_type: "User", remindable_id: create(:user).id).valid?

    task = Task.create!(description: "Payer la taxe fonciere", priority: 3)
    reminder = create(:reminder, remindable: task)
    assert_equal "/", reminder.remindable_summary[:path]
    assert_equal "Payer la taxe fonciere", reminder.remindable_summary[:label]
  end

  test "circuit de livraison : notification, deux relances espacees, puis mail" do
    reminder = create(:reminder)
    assert_nil reminder.delivery_step

    travel 61.minutes do
      assert_equal :push, reminder.delivery_step
      reminder.update_columns(attempts: 1, last_attempt_at: Time.current)
      assert_nil reminder.delivery_step
    end
    travel 72.minutes do
      assert_equal :push, reminder.delivery_step
      reminder.update_columns(attempts: Reminder::MAX_PUSHES, last_attempt_at: Time.current)
    end
    travel 83.minutes do
      assert_equal :email, reminder.delivery_step
      reminder.update_columns(email_sent_at: Time.current)
      assert_nil reminder.delivery_step
    end
  end

  test "une notification vue arrete les relances" do
    reminder = create(:reminder)
    travel 61.minutes do
      reminder.update_columns(attempts: 1, last_attempt_at: 15.minutes.ago)
      assert reminder.acknowledge!
      assert_nil reminder.delivery_step
      assert reminder.due?
    end
  end

  test "reporter remet le circuit a zero et rouvre un rappel termine" do
    reminder = create(:reminder)
    travel 61.minutes do
      reminder.update_columns(attempts: 3, email_sent_at: Time.current, acknowledged_at: Time.current, completed_at: Time.current)
      reminder.snooze!(10.minutes.from_now)
    end
    reminder.reload
    assert_equal 0, reminder.attempts
    assert_nil reminder.email_sent_at
    assert_nil reminder.acknowledged_at
    assert_nil reminder.completed_at
  end

  test "fait : termine un rappel ponctuel, avance un rappel recurrent" do
    once = weekly = nil
    travel_to Time.zone.parse("2026-10-01 08:00") do
      once = create(:reminder)
      weekly = create(:reminder, recurrence: "weekly", remind_at: Time.zone.parse("2026-10-05 09:00"))
    end

    travel_to Time.zone.parse("2026-10-05 09:30") do
      once.done!
      assert once.completed_at.present?

      weekly.done!
      assert_equal Time.zone.parse("2026-10-12 09:00"), weekly.remind_at
      assert_nil weekly.completed_at
    end
  end

  test "un rappel recurrent en retard saute a sa derniere occurrence echue" do
    reminder = nil
    travel_to Time.zone.parse("2026-10-01 08:00") do
      reminder = create(:reminder, recurrence: "daily", remind_at: Time.zone.parse("2026-10-01 09:00"))
    end

    travel_to Time.zone.parse("2026-10-04 10:00") do
      reminder.update_columns(attempts: 3, email_sent_at: 2.days.ago)
      assert reminder.catch_up!
      assert_equal Time.zone.parse("2026-10-04 09:00"), reminder.remind_at
      assert_equal :push, reminder.delivery_step
    end
  end

  test "date lisible en francais, heure de Paris" do
    assert_equal "Lundi 5 octobre à 09:00", Reminder.human_time(Time.zone.parse("2026-10-05 09:00"))
  end
end
