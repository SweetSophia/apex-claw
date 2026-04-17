class TaskHandoff < ApplicationRecord
  include Auditable

  audit_events :create, :update

  belongs_to :task
  belongs_to :from_agent, class_name: "Agent"
  belongs_to :to_agent, class_name: "Agent"

  enum :status, { pending: 0, accepted: 1, rejected: 2, expired: 3 }, default: :pending

  validates :from_agent_id, comparison: { other_than: :to_agent_id, message: "must differ from target agent" }
  validates :context, presence: true
  validate :only_one_pending_handoff_per_task, on: :create, if: :pending?

  scope :for_agent, ->(agent_id) { where(from_agent_id: agent_id).or(where(to_agent_id: agent_id)) }
  scope :for_task, ->(task_id) { where(task_id: task_id) }

  after_create_commit :broadcast_handoff_created

  def accept!
    return false unless pending?
    update!(status: :accepted, responded_at: Time.current)
  end

  def reject!
    return false unless pending?
    update!(status: :rejected, responded_at: Time.current)
  end

  def expire!
    return false unless pending?
    update!(status: :expired, responded_at: Time.current)
  end

  # Expire all pending handoffs older than 5 minutes
  def self.expire_stale!
    pending.where(created_at: ..5.minutes.ago).find_each(&:expire!)
  end

  private

  def only_one_pending_handoff_per_task
    return unless task_id
    return unless self.class.pending.where(task_id: task_id).where.not(id: id).exists?

    errors.add(:task_id, "already has a pending handoff")
  end


  def broadcast_handoff_created
    return unless task&.user_id

    # Broadcast to the user's agents stream
    Turbo::StreamsChannel.broadcast_action_to(
      "agents:#{task.user_id}",
      action: :append,
      target: "handoffs",
      partial: "task_handoffs/handoff",
      locals: { handoff: self }
    )

    # SSE event for API consumers
    ActionCable.server.broadcast(
      "api:events:#{task.user_id}",
      {
        type: "handoff.created",
        data: handoff_json,
        timestamp: Time.current.utc.iso8601
      }.to_json
    )
  end

  def handoff_json
    {
      id: id,
      task_id: task_id,
      from_agent_id: from_agent_id,
      to_agent_id: to_agent_id,
      context: context,
      status: status,
      responded_at: responded_at&.iso8601,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end
end
