class AgentsController < ApplicationController
  before_action :set_agent, only: [:show]

  def index
    @agents = current_user.agents
      .includes(:agent_commands, :assigned_tasks, :claimed_tasks)
      .order(last_heartbeat_at: :desc)
    @agent_health_stats = Agent.health_stats_for(@agents)
  end

  def show
  end

  private

  def set_agent
    @agent = current_user.agents.find(params[:id])
  end
end
