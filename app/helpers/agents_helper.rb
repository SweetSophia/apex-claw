module AgentsHelper
  def agent_status_badge_classes(agent)
    case agent.status
    when "online" then "bg-emerald-500/20 text-emerald-300"
    when "draining" then "bg-yellow-500/20 text-yellow-300"
    when "disabled" then "bg-red-500/20 text-red-300"
    else "bg-white/[0.06] text-[#8a8a92]"
    end
  end

  def agent_health_badge_classes(agent)
    case agent.health_status
    when :healthy then "bg-emerald-500/15 text-emerald-300"
    when :degraded then "bg-amber-500/15 text-amber-300"
    when :draining then "bg-yellow-500/15 text-yellow-300"
    when :disabled then "bg-red-500/15 text-red-300"
    else "bg-white/[0.06] text-[#8a8a92]"
    end
  end

  def agent_last_seen_badge_classes(agent)
    case agent.last_seen_state
    when :live then "bg-emerald-500/15 text-emerald-300"
    when :stale then "bg-amber-500/15 text-amber-300"
    when :disabled then "bg-red-500/15 text-red-300"
    else "bg-white/[0.06] text-[#8a8a92]"
    end
  end

  def agent_status_icon(agent)
    case agent.status
    when "online" then "🟢"
    when "draining" then "🟡"
    when "disabled" then "🔴"
    else "⚫"
    end
  end

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
