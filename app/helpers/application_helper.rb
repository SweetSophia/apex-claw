module ApplicationHelper
  include AppUrlOptions
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

  # Returns a safe SVG string for a known icon name, or raises ArgumentError.
  # All path data is hardcoded — never derived from user input.
  NAV_ICONS = {
    "home" => "M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25",
    "boards" => "M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z",
    "agents" => "M8.25 3v1.5M4.5 3A2.25 2.25 0 006.75 5.25v14.25a2.25 2.25 0 002.25 2.25h6.75a2.25 2.25 0 002.25-2.25V5.25A2.25 2.25 0 0015.75 3h-7.5zM19.5 12h.008v.008H19.5V12zm-.375 0h.008v.008H19.125V12z",
    "skills" => "M14.25 9.75L16.5 12l-2.25 2.25m-4.5 0L7.5 12l2.25-2.25M6 20.25h12A2.25 2.25 0 0020.25 18V6A2.25 2.25 0 0018 3.75H6A2.25 2.25 0 003.75 6v12A2.25 2.25 0 006 20.25z",
    "workflows" => "M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z",
    "handoffs" => "M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5",
    "routing" => "M7.217 10.907a2.25 2.25 0 100 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186l9.566-5.314m-9.566 7.5l9.566 5.314m0 0a2.25 2.25 0 103.935 2.186 2.25 2.25 0 00-3.935-2.186zm0-12.814a2.25 2.25 0 103.933-2.185 2.25 2.25 0 00-3.933 2.185z",
    "presets" => "M6.75 7.5l3 2.25-3 2.25m4.5 0H21m-9.5-6h4.5a2.25 2.25 0 012.25 2.25v6.75a2.25 2.25 0 01-2.25 2.25h-6.75a2.25 2.25 0 01-2.25-2.25V9.75A2.25 2.25 0 016.75 7.5z",
    "settings" => "M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 010 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 010-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z M15 12a3 3 0 11-6 0 3 3 0 016 0z",
    "audit" => "M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
  }.freeze

  # Validates path_data against a strict allowlist pattern (single path d-attribute value)
  SVG_PATH_PATTERN = /\A[MmLlHhVvCcSsQqTtAaZz0-9.,\-+\s]+\z/

  def nav_icon(name)
    path_data = NAV_ICONS[name.to_s]
    raise ArgumentError, "Unknown nav icon: #{name}" unless path_data

    svg_icon(path_data)
  end

  def svg_icon(path_data)
    # Validate path_data to prevent XSS via user-controlled SVG path injection
    unless SVG_PATH_PATTERN.match?(path_data.to_s)
      raise ArgumentError, "Invalid SVG path data"
    end

    %(<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5"><path stroke-linecap="round" stroke-linejoin="round" d="#{path_data}" /></svg>).html_safe
  end

  def agent_online_count(user)
    return 0 unless user

    user.agents.where("last_heartbeat_at > ?", 5.minutes.ago).count
  end

  def any_agent_online?(user)
    agent_online_count(user).positive?
  end

  def marketing_protocol(request: nil)
    resolved_app_protocol(request: request)
  end

  def marketing_host(request: nil)
    resolved_app_url_host(request: request)
  end

  def marketing_base_url(request: nil)
    resolved_app_base_url(request: request)
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
      { title: "Home", subtitle: "Workspace overview", href: home_path, icon: nav_icon(:home), keywords: %w[home workspace dashboard overview], group: "workspace" },
      { title: "Boards", subtitle: "All workspaces", href: boards_path, icon: nav_icon(:boards), keywords: %w[boards workspace kanban], group: "workspace" },
      { title: "Agents", subtitle: "Fleet status and controls", href: agents_path, icon: nav_icon(:agents), keywords: %w[agents agent fleet status controls], group: "operations" },
      { title: "Skills", subtitle: "Reusable knowledge blocks", href: skills_path, icon: nav_icon(:skills), keywords: %w[skills skill knowledge reusable blocks], group: "operations" },
      { title: "Workflows", subtitle: "Trigger runs and automation", href: workflows_path, icon: nav_icon(:workflows), keywords: %w[workflows workflow triggers runs automation], group: "operations" },
      { title: "Handoffs", subtitle: "Transfer templates", href: handoff_templates_path, icon: nav_icon(:handoffs), keywords: %w[handoffs handoff transfer templates], group: "operations" },
      { title: "Routing", subtitle: "Auto-routing rules", href: routing_rules_path, icon: nav_icon(:routing), keywords: %w[routing auto-routing rules router], group: "operations" },
      { title: "Presets", subtitle: "Reusable command presets", href: command_presets_path, icon: nav_icon(:presets), keywords: %w[presets preset commands command reusable], group: "operations" },
      { title: "Settings", subtitle: "Profile and OpenClaw integration", href: settings_path, icon: nav_icon(:settings), keywords: %w[settings profile openclaw integration api token], group: "system" }
    ]

    if user.admin?
      items << { title: "Audit Logs", subtitle: "Admin activity trail", href: admin_audit_logs_path, icon: nav_icon(:audit), keywords: %w[audit logs admin activity trail], group: "system" }
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

    boards = user.boards.select(:id, :name, :icon, :color, :onboarding_seeded).limit(12).to_a
    done_status = command_bar_done_status
    default_board = current_board || boards.find { |board| !board.onboarding? } || boards.first
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
      "# Apex Claw multi-agent registration",
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
