class Note < ApplicationRecord
  validates :title, presence: true

  scope :ordered, -> { order(note_date: :desc, created_at: :desc) }
end
