class TaskArtifact < ApplicationRecord
  belongs_to :task
  has_one_attached :file

  validates :filename, presence: true
  validates :content_type, presence: true
  validates :size, numericality: { greater_than: 0 }

  validate :file_presence

  private

  def file_presence
    errors.add(:file, "must be attached") unless file.attached?
  end
end
