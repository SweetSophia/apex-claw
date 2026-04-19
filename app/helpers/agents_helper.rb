module AgentsHelper
  def agent_visible_tasks(agent, tasks_claimed:, tasks_assigned:, limit: 10)
    combined = []
    seen_ids = {}

    tasks_claimed.each do |task|
      next if seen_ids[task.id]
      combined << task
      seen_ids[task.id] = true
      return combined if combined.size >= limit
    end

    tasks_assigned.each do |task|
      next if seen_ids[task.id]
      combined << task
      seen_ids[task.id] = true
      return combined if combined.size >= limit
    end

    combined
  end
end
