class WorkflowRun < ApplicationRecord
  belongs_to :workflow
  belongs_to :user

  validates :workflow, presence: true

  attribute :trigger_type, :integer, default: 0

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

  before_validation :assign_user_from_workflow

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  private

  def assign_user_from_workflow
    self.user ||= workflow&.user
  end
end
