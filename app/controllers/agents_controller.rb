class AgentsController < ApplicationController
  before_action :set_agent, only: [:show]

  def index
    @agents = current_user.agents
      .includes(:agent_commands, :assigned_tasks, :claimed_tasks)
      .order(last_heartbeat_at: :desc)
    @agent_health_stats = Agent.health_stats_for(@agents)
  end

  def show
    @commands = @agent.agent_commands.order(created_at: :desc).limit(20)
    @total_assigned_count = @agent.assigned_tasks.count
    @total_claimed_count = @agent.claimed_tasks.count
    @tasks_assigned = @agent.assigned_tasks.includes(:board).order(updated_at: :desc).limit(10)
    @tasks_claimed = @agent.claimed_tasks.includes(:board).order(updated_at: :desc).limit(10)
    @recent_completed_tasks = @agent.claimed_tasks.done.includes(:board).order(completed_at: :desc).limit(10)
  end

  private

  def set_agent
    @agent = current_user.agents.find(params[:id])
  end
end
