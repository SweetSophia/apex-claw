class Workflow < ApplicationRecord
  belongs_to :user
  belongs_to :agent, optional: true
  has_many :workflow_runs, dependent: :destroy

  validates :name, presence: true
  validates :execution_mode, presence: true
  validate :agent_belongs_to_user

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
    return false unless runnable?

    update!(last_run_at: Time.current)
    WorkflowRun.create!(
      workflow: self,
      trigger_type: trigger_type,
      status: :pending
    )
  end

  def runnable?
    active? && agent.present? && !agent.archived?
  end

  private

  def agent_belongs_to_user
    return unless agent_id.present?
    return errors.add(:agent_id, "could not be found") unless agent
    errors.add(:agent_id, "must belong to you") unless agent.user_id == user_id
  end
end
