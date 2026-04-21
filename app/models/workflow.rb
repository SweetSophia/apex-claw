class Workflow < ApplicationRecord
  belongs_to :user
  belongs_to :agent
  has_many :workflow_runs, dependent: :destroy

  validates :name, presence: true
  validates :execution_mode, presence: true

  enum :trigger_type, {
    manual: 0,
    schedule: 1,
    webhook: 2
  }

  enum :execution_mode, {
    create_task: 0,
    run_only: 1
  }

  enum :status, {
    active: 0,
    paused: 1,
    archived: 2
  }

  scope :active, -> { where(status: :active) }
  scope :recent, -> { order(updated_at: :desc) }

  def trigger!(trigger_type: :manual)
    return false unless active?
    return false if agent&.archived?

    WorkflowRun.create!(
      workflow: self,
      trigger_type: trigger_type,
      status: :pending
    )
  end

  def runnable?
    active? && agent.present? && !agent.archived?
  end
end
