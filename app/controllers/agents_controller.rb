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
    @tasks_assigned = @agent.assigned_tasks.order(updated_at: :desc).limit(10)
    @tasks_claimed = @agent.claimed_tasks.order(updated_at: :desc).limit(10)
    @recent_completed_tasks = @agent.claimed_tasks.done.order(completed_at: :desc).limit(10)
  end

  private

  def set_agent
    @agent = current_user.agents.find(params[:id])
  end
end
