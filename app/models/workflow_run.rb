class WorkflowRun < ApplicationRecord
  belongs_to :workflow

  validates :workflow, presence: true

  enum :status, {
    pending: 0,
    running: 1,
    completed: 2,
    failed: 3
  }

  enum :trigger_type, {
    manual: 0,
    schedule: 1,
    webhook: 2
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :incomplete, -> { where(status: [:pending, :running]) }

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end
end
