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
  def command_bar_search_items(user, current_board: nil, tasks_scope: nil)
    return [] unless user

    default_board = current_board || user.boards.first
    items = []

    if default_board
      items << {
        kind: "action",
        actionType: "new_task",
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

    items << { kind: "nav", title: "Home", subtitle: "Dashboard", href: home_path, icon: "🏠", keywords: ["home", "dashboard"], featured: true }
    items << { kind: "nav", title: "Agents", subtitle: "Fleet status and controls", href: agents_path, icon: "🤖", keywords: ["agents", "fleet"], featured: true }
    items << { kind: "nav", title: "Settings", subtitle: "Profile and OpenClaw integration", href: settings_path, icon: "⚙️", keywords: ["settings", "profile", "api", "token"], featured: true }

    if user.admin?
      items << { kind: "nav", title: "Audit Logs", subtitle: "Admin activity trail", href: admin_audit_logs_path, icon: "🧾", keywords: ["admin", "audit", "logs"], featured: true }
    end

    open_counts = user.tasks.unscoped.where(user_id: user.id).where.not(status: Task.statuses[:done]).group(:board_id).count
    user.boards.limit(12).each do |board|
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

    task_order = Arel.sql("CASE WHEN status = #{Task.statuses[:done]} THEN 1 ELSE 0 END ASC, updated_at DESC")
    task_source = if tasks_scope
      tasks_scope.includes(:board).reorder(task_order)
    else
      user.tasks.unscoped.where(user_id: user.id).includes(:board).reorder(task_order)
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

end
