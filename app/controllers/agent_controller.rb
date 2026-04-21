class AgentController < ApplicationController
  # CSRF skip: chat endpoint receives XHR from authenticated browser sessions
  # with CSRF token in headers (Turbo/JS auto-attaches). The skip is needed
  # because some agent-driven POST requests may not include the token.
  # TODO: Verify all chat callers send X-CSRF-Token and remove this skip.
  skip_before_action :verify_authenticity_token, only: :chat

  rate_limit to: 30, within: 1.minute, by: -> { current_user&.id || request.remote_ip },
    with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

  def chat
    response = case params[:message_type]
    when "focus"
      build_focus_response
    when "weekly_recap"
      build_weekly_recap_response
    when "ask_agent"
      build_ask_response(params[:message].to_s.strip)
    else
      render json: { error: "Invalid message_type" }, status: :unprocessable_entity and return
    end

    render json: { response: response }
  end

  private

  def tasks
    @tasks ||= current_user.tasks.unscoped.where(user_id: current_user.id)
  end

  def build_focus_response
    today = Date.current
    lines = []

    # Overdue tasks are top priority
    overdue = tasks.where("due_date < ? AND status != ?", today, Task.statuses[:done])
                   .order(due_date: :asc).limit(5).pluck(:name, :due_date)
    overdue.each do |name, due|
      lines << "#{name} — overdue since #{due.strftime("%b %-d")}"
    end

    # Tasks due today
    due_today = tasks.where(due_date: today).where.not(status: :done)
                     .order(priority: :desc).pluck(:name)
    due_today.each do |name|
      lines << "#{name} — due today"
    end

    # In-progress tasks (already started, keep momentum)
    in_progress = tasks.where(status: :in_progress).order(priority: :desc).limit(5).pluck(:name)
    in_progress.each do |name|
      lines << "#{name} — already in progress" unless lines.length >= 5
    end

    # High priority up_next tasks to fill remaining slots
    if lines.length < 3
      up_next = tasks.where(status: :up_next).order(priority: :desc, position: :asc)
                     .limit(3 - lines.length).pluck(:name, :priority)
      up_next.each do |name, priority|
        label = priority == "high" ? "high priority" : "up next"
        lines << "#{name} — #{label}"
      end
    end

    if lines.empty?
      "You're all clear. No overdue tasks, nothing due today, and nothing in progress. Enjoy the space or pick something from your backlog."
    else
      top = lines.first(3).each_with_index.map { |line, i| "#{i + 1}. #{line}" }
      result = "Here's what needs your attention:\n\n#{top.join("\n")}"
      remaining = tasks.where.not(status: :done).count - top.length
      result += "\n\n#{remaining} other open tasks across your boards." if remaining > 0
      result
    end
  end

  def build_weekly_recap_response
    today = Date.current
    week_start = today.beginning_of_week(:monday)

    completed = tasks.where(status: :done).where("completed_at >= ?", week_start)
    completed_names = completed.limit(5).pluck(:name)
    completed_count = completed.count

    in_flight = tasks.where(status: :in_progress).pluck(:name)
    overdue = tasks.where("due_date < ? AND status != ?", today, Task.statuses[:done]).pluck(:name)
    total_open = tasks.where.not(status: :done).count

    # Agent activity this week
    agent_completions = TaskActivity
      .joins(:task)
      .where(tasks: { user_id: current_user.id })
      .where(actor_type: "agent")
      .where("task_activities.created_at >= ?", week_start)
      .count

    lines = []

    # Completed
    if completed_count > 0
      done_text = completed_names.first(3).join(", ")
      done_text += " and #{completed_count - 3} more" if completed_count > 3
      lines << "Done this week (#{completed_count}): #{done_text}."
    else
      lines << "No tasks completed this week yet."
    end

    # In flight
    if in_flight.any?
      lines << "In progress (#{in_flight.length}): #{in_flight.first(3).join(", ")}#{in_flight.length > 3 ? " and #{in_flight.length - 3} more" : ""}."
    end

    # Needs attention
    if overdue.any?
      lines << "Needs attention: #{overdue.length} overdue — #{overdue.first(3).join(", ")}."
    end

    # Agent contribution
    if agent_completions > 0
      lines << "Your agent handled #{agent_completions} actions this week."
    end

    lines << "#{total_open} tasks still open." if total_open > 0

    lines.join("\n\n")
  end

  def build_ask_response(message)
    return "Try asking about your tasks, or use the focus and recap actions." if message.blank?

    q = message.downcase

    if q.match?(/overdue|late|missed|behind/)
      overdue = tasks.where("due_date < ? AND status != ?", Date.current, Task.statuses[:done])
                     .order(due_date: :asc).pluck(:name, :due_date)
      if overdue.any?
        lines = overdue.first(5).map { |name, due| "#{name} — due #{due.strftime("%b %-d")}" }
        "You have #{overdue.length} overdue tasks:\n\n#{lines.join("\n")}"
      else
        "No overdue tasks. You're on track."
      end

    elsif q.match?(/progress|working|doing|current/)
      in_progress = tasks.where(status: :in_progress).pluck(:name)
      if in_progress.any?
        "Currently in progress (#{in_progress.length}):\n\n#{in_progress.first(5).join("\n")}"
      else
        "Nothing in progress right now."
      end

    elsif q.match?(/done|complete|finish/)
      week_start = Date.current.beginning_of_week(:monday)
      done = tasks.where(status: :done).where("completed_at >= ?", week_start).pluck(:name)
      if done.any?
        "Completed this week (#{done.length}):\n\n#{done.first(5).join("\n")}"
      else
        "Nothing completed this week yet."
      end

    elsif q.match?(/board|project/)
      boards = current_user.boards.includes(:tasks)
      lines = boards.map do |b|
        open_count = b.tasks.reject(&:completed).length
        "#{b.icon} #{b.name} — #{open_count} open tasks"
      end
      lines.join("\n")

    elsif q.match?(/blocked|stuck|help/)
      blocked = tasks.where(blocked: true).where.not(status: :done).pluck(:name)
      if blocked.any?
        "Blocked tasks (#{blocked.length}):\n\n#{blocked.first(5).join("\n")}"
      else
        "No blocked tasks right now."
      end

    elsif q.match?(/agent|openclaw/)
      agents = current_user.agents.order(last_heartbeat_at: :desc)
      if agents.any?
        names = agents.first(3).map do |agent|
          heartbeat = agent.last_heartbeat_at.present? ? "#{time_ago_in_words(agent.last_heartbeat_at)} ago" : "never"
          "#{agent.name} (#{agent.status}, heartbeat #{heartbeat})"
        end
        assigned = tasks.where(assigned_to_agent: true, completed: false).count
        "Registered agents: #{names.join(', ')}. #{assigned} tasks currently assigned to agents."
      else
        "No registered agents yet. Go to Settings and generate a join token for each agent."
      end

    elsif q.match?(/how many|count|total|stat/)
      total = tasks.where.not(status: :done).count
      by_status = tasks.where.not(status: :done).group(:status).count
      lines = by_status.map { |status, count| "#{status.titleize}: #{count}" }
      "#{total} open tasks:\n\n#{lines.join("\n")}"

    else
      total_open = tasks.where.not(status: :done).count
      in_progress = tasks.where(status: :in_progress).count
      "You have #{total_open} open tasks, #{in_progress} in progress. Try asking about what's overdue, in progress, blocked, or what your boards look like."
    end
  end
end
