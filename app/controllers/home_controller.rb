class HomeController < ApplicationController
  def show
    today = Date.current
    start_of_today = Time.current.beginning_of_day

    @user = current_user
    @boards = current_user.boards
    @registered_agents = current_user.agents.active.order(last_heartbeat_at: :desc, created_at: :desc)
    @registered_agents_count = @registered_agents.count
    @skills_count = current_user.skills.count
    @workflow_count = current_user.workflows.count
    @command_presets_count = current_user.command_presets.count
    @handoff_templates_count = current_user.handoff_templates.count
    @routing_rules_count = current_user.routing_rules.count
    @open_tasks_counts = current_user.tasks.reorder(nil).where(completed: false).group(:board_id).count
    boards = @boards.to_a
    @onboarding_boards, @non_onboarding_boards = boards.partition(&:onboarding?)
    @active_projects = @non_onboarding_boards.presence || boards

    # Today's tasks: due today + active tasks (up_next, in_progress)
    @today_tasks = current_user.tasks
      .where("due_date = ? OR status IN (?)", today, [1, 2]) # up_next=1, in_progress=2
      .where(completed: false)
      .includes(:board)
      .reorder(position: :asc)
      .limit(10)

    # Also include recently completed today
    @completed_today = current_user.tasks
      .where(completed: true)
      .where("completed_at >= ?", start_of_today)
      .includes(:board)
      .reorder(completed_at: :desc)
      .limit(5)

    @all_today_tasks = @today_tasks + @completed_today

    # Agent tasks currently being worked on
    @agent_tasks_count = current_user.tasks.where(assigned_to_agent: true, completed: false).count
    @agent_online_count = @registered_agents
      .where(status: Agent.statuses[:online])
      .where("last_heartbeat_at > ?", Agent::HEARTBEAT_STALE_AFTER.ago)
      .count

    # Agent updates (last 24h)
    @agent_updates = TaskActivity
      .joins(:task)
      .where(tasks: { user_id: current_user.id })
      .where(actor_type: "agent")
      .where("task_activities.created_at > ?", 24.hours.ago)
      .includes(:task)
      .order(created_at: :desc)
      .limit(5)

    # Weekly stats — count tasks completed each day
    # "done" can be tracked via "moved" action with new_value="done" or "completed" action
    week_start = today.beginning_of_week(:monday)
    @week_stats = (0..6).map do |i|
      date = week_start + i.days
      base = TaskActivity
        .joins(:task)
        .where(tasks: { user_id: current_user.id })
        .where(task_activities: { created_at: date.all_day })
        .where("(task_activities.action = 'moved' AND task_activities.new_value = 'done') OR task_activities.action = 'completed'")

      {
        day: date.strftime("%a"),
        date: date,
        you: base.where.not(actor_type: "agent").count,
        agent: base.where(actor_type: "agent").count
      }
    end

    # Summary counts
    @completed_count = @week_stats.sum { |d| d[:you] + d[:agent] }
    @in_progress_count = current_user.tasks.where(status: :in_progress, completed: false).count
    @upcoming_count = current_user.tasks.where(status: [:inbox, :up_next], completed: false).count
    @completed_today_count = @completed_today.count
  end
end
