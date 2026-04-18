class Agent < ApplicationRecord
  include Auditable

  HEARTBEAT_STALE_AFTER = 5.minutes
  HEALTH_WINDOW = 24.hours

  audit_events :update

  belongs_to :user

  has_many :assigned_tasks,
           class_name: "Task",
           foreign_key: :assigned_agent_id,
           inverse_of: :assigned_agent,
           dependent: :nullify
  has_many :claimed_tasks,
           class_name: "Task",
           foreign_key: :claimed_by_agent_id,
           inverse_of: :claimed_by_agent,
           dependent: :nullify
  has_one :agent_rate_limit, dependent: :destroy
  has_many :agent_tokens, dependent: :destroy
  has_many :agent_commands, dependent: :destroy
  has_many :task_activities,
           class_name: "TaskActivity",
           foreign_key: :actor_agent_id,
           inverse_of: :actor_agent,
           dependent: :nullify
  has_many :sent_handoffs, class_name: "TaskHandoff", foreign_key: :from_agent_id, dependent: :destroy
  has_many :received_handoffs, class_name: "TaskHandoff", foreign_key: :to_agent_id, dependent: :destroy

  enum :status, {
    offline: 0,
    online: 1,
    draining: 2,
    disabled: 3
  }, default: :offline

  validates :name, presence: true

  def heartbeat_stale?
    return true if last_heartbeat_at.blank?

    last_heartbeat_at < HEARTBEAT_STALE_AFTER.ago
  end

  def health_status
    return :disabled if disabled?
    return :offline if offline? || heartbeat_stale?
    return :draining if draining?

    task_runner_active? ? :healthy : :degraded
  end

  def health_badge_label
    case health_status
    when :healthy then "Healthy"
    when :degraded then "Degraded"
    when :draining then "Draining"
    when :disabled then "Disabled"
    else "Offline"
    end
  end

  def uptime_seconds
    metadata_value("uptime_seconds")&.to_i
  end

  def uptime_label
    seconds = uptime_seconds
    return "Unknown" if seconds.blank? || seconds <= 0

    ApplicationController.helpers.distance_of_time_in_words(seconds)
  end

  def task_runner_active?
    ActiveModel::Type::Boolean.new.cast(metadata_value("task_runner_active"))
  end

  def recent_completed_tasks_count(window: HEALTH_WINDOW)
    claimed_tasks.done.where("completed_at >= ?", window.ago).count
  end

  def recent_commands_count(window: HEALTH_WINDOW)
    agent_commands.where(created_at: window.ago..).count
  end

  def recent_failed_commands_count(window: HEALTH_WINDOW)
    agent_commands.failed.where(created_at: window.ago..).count
  end

  def recent_command_error_rate(window: HEALTH_WINDOW)
    total = recent_commands_count(window: window)
    return 0 if total.zero?

    ((recent_failed_commands_count(window: window).to_f / total) * 100).round
  end

  def pending_commands_count
    agent_commands.pending.count
  end

  private

  def metadata_value(key)
    metadata&.[](key) || metadata&.[](key.to_sym)
  end
end
