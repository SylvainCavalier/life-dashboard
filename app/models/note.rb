# == Schema Information
#
# Table name: notes
#
#  id         :bigint           not null, primary key
#  content    :text
#  important  :boolean          default(FALSE), not null
#  note_date  :date             not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_notes_on_important  (important)
#  index_notes_on_note_date  (note_date)
#
class Note < ApplicationRecord
  validates :title, presence: true

  scope :ordered, -> { order(note_date: :desc, created_at: :desc) }
end
