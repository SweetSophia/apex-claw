module ApplicationHelper
  COMMAND_BAR_STATUS_LABELS = {
    "inbox" => "Inbox",
    "up_next" => "Up Next",
    "in_progress" => "In Progress",
    "in_review" => "In Review",
    "done" => "Done"
  }.freeze

  BOARD_COLOR_HEX = {
    "gray" => "#888888", "red" => "#ef4444", "orange" => "#f97316", "amber" => "#fbbf24",
    "yellow" => "#eab308", "lime" => "#84cc16", "green" => "#34d399", "emerald" => "#10b981",
    "teal" => "#14b8a6", "cyan" => "#06b6d4", "sky" => "#0ea5e9", "blue" => "#60a5fa",
    "indigo" => "#6366f1", "violet" => "#8b5cf6", "purple" => "#a78bfa", "fuchsia" => "#d946ef",
    "pink" => "#ec4899", "rose" => "#f43f5e"
  }.freeze

  def board_hex_color(board)
    BOARD_COLOR_HEX[board.color] || "#888888"
  end

  # Convert hex color to rgba string
  def hex_to_rgba(hex, alpha)
    hex = hex.gsub("#", "")
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)
    "rgba(#{r},#{g},#{b},#{alpha})"
  end

  def time_greeting
    hour = Time.current.hour
    if hour < 12
      "Good morning"
    elsif hour < 17
      "Good afternoon"
    else
      "Good evening"
    end
  end
  def activity_icon_bg(activity)
    case activity.action
    when "created"
      "bg-status-info/20"
    when "moved"
      "bg-purple-900/30"
    when "updated"
      "bg-status-warning/20"
    else
      "bg-bg-elevated"
    end
  end

  def activity_icon(activity)
    case activity.action
    when "created"
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-status-info"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>'.html_safe
    when "moved"
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-purple-400"><path stroke-linecap="round" stroke-linejoin="round" d="M7.5 21 3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5" /></svg>'.html_safe
    when "updated"
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-status-warning"><path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Z" /></svg>'.html_safe
    else
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-3 h-3 text-content-secondary"><path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>'.html_safe
    end
  end
  def workspace_nav_items(user)
    return [] unless user

    items = [
      { title: "Home", subtitle: "Workspace overview", href: home_path, icon: "🏠", keywords: %w[home workspace dashboard overview] },
      { title: "Agents", subtitle: "Fleet status and controls", href: agents_path, icon: "🤖", keywords: %w[agents agent fleet status controls] },
      { title: "Skills", subtitle: "Reusable knowledge blocks", href: skills_path, icon: "🧠", keywords: %w[skills skill knowledge reusable blocks] },
      { title: "Workflows", subtitle: "Triggers runs and automation", href: workflows_path, icon: "🪄", keywords: %w[workflows workflow triggers runs automation] },
      { title: "Handoffs", subtitle: "Transfer templates", href: handoff_templates_path, icon: "🔁", keywords: %w[handoffs handoff transfer templates] },
      { title: "Routing", subtitle: "Auto-routing rules", href: routing_rules_path, icon: "🧭", keywords: %w[routing auto-routing rules router] },
      { title: "Presets", subtitle: "Reusable command presets", href: command_presets_path, icon: "🧰", keywords: %w[presets preset commands command reusable] },
      { title: "Settings", subtitle: "Profile and OpenClaw integration", href: settings_path, icon: "⚙️", keywords: %w[settings profile openclaw integration api token] }
    ]

    if user.admin?
      items << { title: "Audit Logs", subtitle: "Admin activity trail", href: admin_audit_logs_path, icon: "🧾", keywords: %w[audit logs admin activity trail] }
    end

    items
  end

  def onboarding_board?(board)
    board.present? && board.onboarding?
  end

  def nav_item_active?(item, active_path)
    return false if item.blank? || active_path.blank?

    href = item[:href].to_s
    return false if href.blank?
    return active_path == href if href == home_path

    active_path == href || active_path.start_with?("#{href}/")
  end

  def command_bar_search_items(user, current_board: nil, tasks_scope: nil)
    return [] unless user

    boards = user.boards.select(:id, :name, :icon, :color).limit(12).to_a
    done_status = command_bar_done_status
    default_board = current_board || boards.first
    items = []

    if default_board
      items << {
        kind: "action",
        actionType: "new_task",
        boardId: default_board.id,
        title: "New task",
        subtitle: "Create in #{default_board.name}",
        href: board_path(default_board, new_task: 1),
        icon: "➕",
        keywords: ["new task", "add card", "create task", default_board.name],
        featured: true
      }
    end

    items << {
      kind: "action",
      actionType: "agent",
      title: "Ask about tasks",
      subtitle: "Query your boards",
      icon: "⌨️",
      keywords: ["ask", "agent", "tasks", "query"],
      featured: true
    }

    items << {
      kind: "action",
      title: "What should I focus on?",
      subtitle: "Top priorities",
      icon: "☀️",
      agentPrompt: "What should I focus on today?",
      keywords: ["focus", "priority", "today"],
      featured: true
    }

    items << {
      kind: "action",
      title: "Weekly recap",
      subtitle: "Summary of progress",
      icon: "📊",
      agentPrompt: "Give me a weekly recap",
      keywords: ["weekly", "recap", "summary", "progress"],
      featured: true
    }

    workspace_nav_items(user).each do |item|
      items << {
        kind: "nav",
        title: item[:title],
        subtitle: item[:subtitle],
        href: item[:href],
        icon: item[:icon],
        keywords: Array(item[:keywords]).presence || [item[:title], item[:subtitle]],
        featured: true
      }
    end

    board_ids = boards.map(&:id)
    open_counts = if board_ids.any?
      user.tasks.unscoped.where(user_id: user.id, board_id: board_ids).where.not(status: done_status).group(:board_id).count
    else
      {}
    end

    boards.each do |board|
      items << {
        kind: "board",
        title: board.name,
        subtitle: "#{open_counts[board.id] || 0} open tasks",
        href: board_path(board),
        icon: board.icon,
        keywords: [board.name, "board", board.color],
        featured: current_board.nil? || current_board.id != board.id
      }
    end

    task_table = Task.arel_table
    task_order = Arel::Nodes::Case.new
      .when(task_table[:status].eq(done_status)).then(1)
      .else(0)

    task_source = if tasks_scope
      tasks_scope.includes(:board).reorder(task_order.asc, updated_at: :desc)
    else
      user.tasks.unscoped.where(user_id: user.id).includes(:board).reorder(task_order.asc, updated_at: :desc)
    end

    task_source.limit(150).each do |task|
      next unless task.board

      subtitle = "#{task.board.icon} #{task.board.name} · #{command_bar_status_label(task.status)}"
      subtitle += " · Due #{task.due_date.strftime('%b %-d')}" if task.due_date.present?

      items << {
        kind: "task",
        title: task.name,
        subtitle: subtitle,
        href: board_path(task.board, task_id: task.id),
        icon: command_bar_status_icon(task.status),
        keywords: [task.name, task.status, task.board.name, *Array(task.tags)],
        featured: false
      }
    end

    items
  end

  def command_bar_status_label(status)
    COMMAND_BAR_STATUS_LABELS[status.to_s] || status.to_s.titleize
  end

  def command_bar_status_icon(status)
    {
      "inbox" => "○",
      "up_next" => "→",
      "in_progress" => "◔",
      "in_review" => "◌",
      "done" => "✓"
    }[status.to_s] || "•"
  end

  def registered_agents_for(user)
    return Agent.none unless user

    user.agents.order(last_heartbeat_at: :desc, created_at: :desc)
  end

  def primary_registered_agent_for(user)
    registered_agents_for(user).first
  end

  def any_registered_agents?(user)
    registered_agents_for(user).exists?
  end

  def agent_registration_prompt(api_url:, api_token:, join_token:)
    token_value = join_token.presence || "Generate one in Settings"
    example_join_token = join_token.presence || "jt_xxx"

    [
      "# ClawDeck multi-agent registration",
      "",
      "IMPORTANT:",
      "- This join token is SINGLE-USE. Generate a fresh one for each new agent registration.",
      "- Register the agent you are running RIGHT NOW.",
      "- Do NOT reuse another agent's payload, name, hostname, or host_uid.",
      "- Example: Cybera must send name=\"cybera\". Miku must send name=\"miku\". Cylena must send name=\"cylena\".",
      "- Do not copy Cylena's identity unless you are actually registering Cylena.",
      "",
      "Use the real multi-agent flow, not just presence headers.",
      "",
      "API URL: #{api_url}",
      "User API token: #{api_token}",
      "Join token: #{token_value}",
      "",
      "Register once with:",
      "POST /agents/register",
      "{",
      "  \"join_token\": \"#{example_join_token}\",",
      "  \"agent\": {",
      "    \"name\": \"your-agent-name\",",
      "    \"hostname\": \"your-host\",",
      "    \"host_uid\": \"stable-host-id-for-this-agent\",",
      "    \"platform\": \"linux-x64\",",
      "    \"version\": \"1.0.0\",",
      "    \"tags\": [\"openclaw\"],",
      "    \"metadata\": {\"runtime\": \"openclaw\"}",
      "  }",
      "}",
      "",
      "Then store the returned agent_token and use it for:",
      "- POST /agents/:id/heartbeat",
      "- GET /tasks/next",
      "- PATCH /tasks/:id/claim",
      "- PATCH /tasks/:id",
      "- PATCH /tasks/:id/complete",
      "- commands, handoffs, artifacts",
      "",
      "Do not rely on X-Agent-Name / X-Agent-Emoji alone. Those do not register a real agent."
    ].join("\n")
  end

  private

  def command_bar_done_status
    Integer(Task.statuses.fetch("done"))
  end
end
