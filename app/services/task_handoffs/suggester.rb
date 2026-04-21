module TaskHandoffs
  class Suggester
    DEFAULT_LIMIT = 5
    DEFAULT_MAX_CONCURRENT_TASKS = 5
    SKILLS_WEIGHT = 40.0
    AVAILABILITY_WEIGHT = 30.0
    WORKLOAD_WEIGHT = 30.0

    def initialize(task)
      @task = task
    end

    # Returns an array of hashes: [{ agent:, score:, reasons: }]
    # Sorted by score descending, max `limit` results.
    def suggest(limit: DEFAULT_LIMIT)
      limit = (limit || DEFAULT_LIMIT).to_i
      return [] if limit <= 0 || task&.user_id.blank?

      candidate_agents
        .map { |agent| build_suggestion(agent) }
        .sort_by { |suggestion| sort_key_for(suggestion) }
        .first(limit)
        .map { |suggestion| suggestion.slice(:agent, :score, :reasons) }
    end

    private

    attr_reader :task

    def candidate_agents
      @candidate_agents ||= begin
        scope = Agent
          .includes(:skills)
          .where(user_id: task.user_id)
          .active
          .where(status: Agent.statuses[:online])

        if excluded_agent_ids.any?
          scope = scope.where.not(id: excluded_agent_ids)
        end

        scope.to_a
      end
    end

    def excluded_agent_ids
      @excluded_agent_ids ||= [ task.assigned_agent_id, task.claimed_by_agent_id ].compact.uniq
    end

    def build_suggestion(agent)
      matching_count = matching_skills_count(agent)
      current_workload = active_tasks_count(agent)
      max_tasks = max_concurrent_tasks_for(agent)

      {
        agent: agent,
        score: total_score_for(agent, matching_count:, current_workload:, max_tasks:).round(2),
        reasons: reasons_for(agent, matching_count:, current_workload:, max_tasks:),
        matching_skills_count: matching_count,
        active_tasks_count: current_workload
      }
    end

    def total_score_for(agent, matching_count:, current_workload:, max_tasks:)
      skills_score_for(matching_count) +
        availability_score_for(agent) +
        workload_score_for(current_workload, max_tasks)
    end

    def skills_score_for(matching_count)
      return SKILLS_WEIGHT if required_skill_names.empty?

      (matching_count.to_f / required_skill_names.size) * SKILLS_WEIGHT
    end

    def availability_score_for(agent)
      agent.active_for_work? ? AVAILABILITY_WEIGHT : 0.0
    end

    def workload_score_for(current_workload, max_tasks)
      remaining_capacity_ratio = 1.0 - (current_workload.to_f / max_tasks)
      remaining_capacity_ratio = remaining_capacity_ratio.clamp(0.0, 1.0)

      remaining_capacity_ratio * WORKLOAD_WEIGHT
    end

    def reasons_for(agent, matching_count:, current_workload:, max_tasks:)
      [
        skills_reason_for(matching_count),
        availability_reason_for(agent),
        workload_reason_for(current_workload, max_tasks)
      ]
    end

    def skills_reason_for(matching_count)
      return "Skills match: no requirements" if required_skill_names.empty?

      "Skills match: #{matching_count}/#{required_skill_names.size}"
    end

    def availability_reason_for(agent)
      agent.active_for_work? ? "Available" : "Unavailable"
    end

    def workload_reason_for(current_workload, max_tasks)
      reason = "Workload: #{current_workload}/#{max_tasks} tasks"
      reason += " (at capacity)" if current_workload >= max_tasks
      reason
    end

    def sort_key_for(suggestion)
      [
        -suggestion[:score],
        -suggestion[:matching_skills_count],
        suggestion[:active_tasks_count],
        suggestion[:agent].name.to_s.downcase,
        suggestion[:agent].id
      ]
    end

    def required_skill_names
      @required_skill_names ||= Array(
        task.respond_to?(:required_skills) ? task.required_skills : nil
      )
        .filter_map { |skill_name| skill_name.to_s.strip.downcase.presence }
        .uniq
    end

    def matching_skills_count(agent)
      return 0 if required_skill_names.empty?

      agent_skill_names = agent.skills.map { |skill| skill.name.to_s.strip.downcase }.uniq
      (required_skill_names & agent_skill_names).size
    end

    def active_tasks_count(agent)
      active_task_counts.fetch(agent.id, 0)
    end

    def active_task_counts
      @active_task_counts ||= begin
        agent_ids = candidate_agents.map(&:id)
        if agent_ids.empty?
          {}
        else
          Task.unscoped
            .where(user_id: task.user_id, assigned_agent_id: agent_ids)
            .where.not(status: Task.statuses[:done])
            .group(:assigned_agent_id)
            .count
        end
      end
    end

    def max_concurrent_tasks_for(agent)
      value = agent.max_concurrent_tasks.presence || DEFAULT_MAX_CONCURRENT_TASKS
      value.to_i.positive? ? value.to_i : DEFAULT_MAX_CONCURRENT_TASKS
    end
  end
end
