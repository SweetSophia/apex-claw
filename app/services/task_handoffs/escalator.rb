module TaskHandoffs
  class Escalator
    DEFAULT_BLOCK_TIMEOUT_MINUTES = 30
    DEFAULT_MAX_ESCALATIONS = 3
    DEFAULT_MESSAGE_TEMPLATE = "Task has been blocked and requires attention"

    def self.escalate_blocked_tasks!
      new.run
    end

    def run
      escalations_created = 0

      find_eligible_tasks.reorder(nil).find_each do |task|
        task.with_lock do
          next unless should_escalate?(task)

          from_agent = source_agent_for(task)
          next unless from_agent

          target_agent = find_target_agent(task)
          next unless target_agent

          TaskHandoff.create!(
            task: task,
            from_agent: from_agent,
            to_agent: target_agent,
            context: build_context(task, escalation_config_for(task)),
            escalation: true,
            reason: "auto-escalated"
          )

          escalations_created += 1
        end
      end

      escalations_created
    end

    private

    def find_eligible_tasks
      Task.where(blocked: true)
        .where("escalation_config @> ?", { enabled: true }.to_json)
        .where.not(status: :done)
        .includes(:user, :assigned_agent, :claimed_by_agent)
    end

    def should_escalate?(task)
      return false unless task.blocked?
      return false if task.done?

      config = escalation_config_for(task)

      timeout_elapsed?(task, config) &&
        escalations_count(task) < max_escalations_for(config) &&
        !task.handoffs.pending.exists? &&
        source_agent_for(task).present?
    end

    def find_target_agent(task)
      from_agent = source_agent_for(task)

      configured_target = configured_target_agent(task)
      return configured_target if suitable_target_agent?(configured_target, excluding: from_agent)

      TaskHandoffs::Suggester.new(task)
        .suggest(limit: 5)
        .lazy
        .map { |suggestion| suggestion[:agent] || suggestion["agent"] }
        .find { |agent| suitable_target_agent?(agent, excluding: from_agent) }
    end

    def build_context(task, config)
      template = config["message_template"].presence || DEFAULT_MESSAGE_TEMPLATE
      timeout = block_timeout_minutes_for(config)

      template.gsub("{{timeout}}", timeout.to_s)
              .gsub("{{task_name}}", task.name.to_s)
              .gsub("{{task_status}}", task.status.to_s)
              .gsub("{{task_priority}}", task.priority.to_s)
    end

    def escalation_config_for(task)
      task.escalation_config.is_a?(Hash) ? task.escalation_config : {}
    end

    def timeout_elapsed?(task, config)
      reference_time = task.created_at
      return false if reference_time.blank?

      reference_time <= block_timeout_minutes_for(config).minutes.ago
    end

    def escalations_count(task)
      task.handoffs.escalated.count
    end

    def configured_target_agent(task)
      target_agent_id = escalation_config_for(task)["target_agent_id"]
      return if target_agent_id.blank?

      task.user.agents.find_by(id: target_agent_id)
    end

    def suitable_target_agent?(agent, excluding:)
      agent.present? && agent.active_for_work? && agent.id != excluding&.id
    end

    def source_agent_for(task)
      task.claimed_by_agent || task.assigned_agent
    end

    def block_timeout_minutes_for(config)
      positive_integer(config["block_timeout_minutes"], default: DEFAULT_BLOCK_TIMEOUT_MINUTES)
    end

    def max_escalations_for(config)
      positive_integer(config["max_escalations"], default: DEFAULT_MAX_ESCALATIONS)
    end

    def positive_integer(value, default:)
      integer = value.to_i
      integer.positive? ? integer : default
    end
  end
end
