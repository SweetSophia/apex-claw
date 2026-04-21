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
  has_many :command_presets, dependent: :nullify
  has_many :task_activities,
           class_name: "TaskActivity",
           foreign_key: :actor_agent_id,
           inverse_of: :actor_agent,
           dependent: :nullify
  has_many :sent_handoffs, class_name: "TaskHandoff", foreign_key: :from_agent_id, dependent: :destroy
  has_many :received_handoffs, class_name: "TaskHandoff", foreign_key: :to_agent_id, dependent: :destroy
  belongs_to :archived_by, class_name: "User", optional: true
  has_many :agent_skills, dependent: :destroy
  has_many :skills, through: :agent_skills
  has_many :workflows, dependent: :nullify

  enum :status, {
    offline: 0,
    online: 1,
    draining: 2,
    disabled: 3
  }, default: :offline

  validates :name, presence: true
  validates :instructions, length: { maximum: 65_535 }, allow_blank: true
  validates :max_concurrent_tasks, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: false
  validates :model, length: { maximum: 255 }, allow_blank: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :with_skill, ->(skill_id) { joins(:agent_skills).where(agent_skills: { skill_id: skill_id }) }

  after_update_commit :broadcast_dashboard_update, if: :dashboard_summary_changed?

  def self.broadcast_dashboard_update(agent, sections: [:card, :summary, :commands, :recent_work, :tasks, :metadata, :tags])
    return unless agent&.user_id

    stats = health_stats_for([ agent ])[agent.id] || {}

    if sections.include?(:card)
      Turbo::StreamsChannel.broadcast_action_to(
        "agents:#{agent.user_id}",
        action: :replace,
        target: "agent_#{agent.id}",
        partial: "agents/agent_card",
        locals: { agent: agent, health_stats: stats }
      )
    end

    if sections.include?(:summary)
      Turbo::StreamsChannel.broadcast_action_to(
        "agents:#{agent.user_id}",
        action: :replace,
        target: "agent_show_summary_#{agent.id}",
        partial: "agents/show_summary",
        locals: { agent: agent, health_stats: stats }
      )
    end

    if sections.include?(:recent_work)
      Turbo::StreamsChannel.broadcast_action_to(
        "agents:#{agent.user_id}",
        action: :replace,
        target: "agent_show_recent_work_#{agent.id}",
        partial: "agents/show_recent_work",
        locals: { agent: agent }
      )
    end

    if sections.include?(:tags)
      Turbo::StreamsChannel.broadcast_action_to(
        "agents:#{agent.user_id}",
        action: :replace,
        target: "agent_show_tags_#{agent.id}",
        partial: "agents/show_tags",
        locals: { agent: agent }
      )
    end

    if sections.include?(:metadata)
      Turbo::StreamsChannel.broadcast_action_to(
        "agents:#{agent.user_id}",
        action: :replace,
        target: "agent_show_metadata_#{agent.id}",
        partial: "agents/show_metadata",
        locals: { agent: agent }
      )
    end

    if sections.include?(:commands)
      Turbo::StreamsChannel.broadcast_action_to(
        "agents:#{agent.user_id}",
        action: :replace,
        target: "agent_show_commands_#{agent.id}",
        partial: "agents/show_commands",
        locals: { agent: agent }
      )
    end

    if sections.include?(:tasks)
      Turbo::StreamsChannel.broadcast_action_to(
        "agents:#{agent.user_id}",
        action: :replace,
        target: "agent_show_tasks_#{agent.id}",
        partial: "agents/show_tasks",
        locals: { agent: agent }
      )
    end
  end

  def self.health_stats_for(agents, window: HEALTH_WINDOW)
    agent_ids = Array(agents).map(&:id)
    return {} if agent_ids.empty?

    window_start = window.ago
    completed_counts = Task.unscoped.done
      .where(claimed_by_agent_id: agent_ids)
      .where("completed_at >= ?", window_start)
      .reorder(nil)
      .group(:claimed_by_agent_id)
      .count
    command_counts = AgentCommand
      .where(agent_id: agent_ids, created_at: window_start..)
      .group(:agent_id)
      .count
    failed_counts = AgentCommand.failed
      .where(agent_id: agent_ids, created_at: window_start..)
      .group(:agent_id)
      .count
    pending_counts = AgentCommand.pending
      .where(agent_id: agent_ids)
      .group(:agent_id)
      .count
    claimed_counts = Task.unscoped
      .where(claimed_by_agent_id: agent_ids)
      .where.not(status: Task.statuses[:done])
      .group(:claimed_by_agent_id)
      .count
    assigned_counts = Task.unscoped
      .where(assigned_agent_id: agent_ids)
      .where.not(status: Task.statuses[:done])
      .group(:assigned_agent_id)
      .count

    agent_ids.each_with_object({}) do |agent_id, stats|
      total_commands = command_counts[agent_id].to_i
      failed_commands = failed_counts[agent_id].to_i

      stats[agent_id] = {
        completed: completed_counts[agent_id].to_i,
        commands: total_commands,
        failed: failed_commands,
        pending: pending_counts[agent_id].to_i,
        claimed_count: claimed_counts[agent_id].to_i,
        assigned_count: assigned_counts[agent_id].to_i,
        error_rate: total_commands.zero? ? 0 : ((failed_commands.to_f / total_commands) * 100).round
      }
    end
  end

  def archived?
    archived_at.present?
  end

  def archive!(archived_by_user)
    update!(archived_at: Time.current, archived_by: archived_by_user)
  end

  def restore!
    update!(archived_at: nil, archived_by: nil)
  end

  def active_for_work?
    online? && !archived?
  end

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

    duration = ActiveSupport::Duration.build(seconds)
    parts = []
    parts << "#{duration.parts[:days]}d" if duration.parts[:days].to_i > 0
    parts << "#{duration.parts[:hours]}h" if duration.parts[:hours].to_i > 0
    parts << "#{duration.parts[:minutes]}m" if duration.parts[:minutes].to_i > 0
    parts.any? ? parts.join(" ") : "< 1m"
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

  def runtime_provider
    metadata_value("provider").presence || model.presence || "OpenClaw"
  end

  def last_seen_label
    return "Never" if last_heartbeat_at.blank?

    "#{ActionController::Base.helpers.time_ago_in_words(last_heartbeat_at)} ago"
  end

  def last_seen_state
    return :never if last_heartbeat_at.blank?
    return :stale if heartbeat_stale?

    online? ? :live : status.to_sym
  end

  def health_alerts(health_stats: nil)
    stats = health_stats || self.class.health_stats_for([self])[id] || {}
    alerts = []
    alerts << "Heartbeat is stale" if heartbeat_stale?
    alerts << "Task runner is idle" unless task_runner_active?
    alerts << "#{stats[:failed]} command failures in 24h" if stats[:failed].to_i.positive?
    alerts << "#{stats[:pending]} commands pending" if stats[:pending].to_i >= 3
    alerts
  end

  private

  def audit_ignored_change_keys
    super + %w[custom_env custom_args]
  end

  def broadcast_dashboard_update
    sections = [:card, :summary]
    sections << :metadata if previous_changes.key?("metadata")
    sections << :tags if previous_changes.key?("tags")

    self.class.broadcast_dashboard_update(self, sections: sections)
  end

  def dashboard_summary_changed?
    (previous_changes.keys & %w[
      name status hostname platform version last_heartbeat_at
      metadata tags archived_at instructions model
      max_concurrent_tasks custom_env custom_args
    ]).any?
  end

  def metadata_value(key)
    metadata&.[](key) || metadata&.[](key.to_sym)
  end
end
