class AgentsController < ApplicationController
  before_action :set_agent, only: [ :show ]
  before_action :require_owner_user!, only: [ :update_instructions, :update_config, :update_settings, :archive, :restore, :assign_skill, :remove_skill ]

  def index
    @agents = current_user.agents
      .includes(:agent_commands, :assigned_tasks, :claimed_tasks)
      .order(last_heartbeat_at: :desc)
    @agent_health_stats = Agent.health_stats_for(@agents)
    @live_agent_count = @agents.count { |agent| agent.last_seen_state == :live }
    @stale_agent_count = @agents.count { |agent| agent.last_seen_state == :stale }
    @pending_command_count = @agents.sum { |agent| @agent_health_stats.fetch(agent.id, {})[:pending].to_i }
  end

  def show
  end

  def update_instructions
    if @agent.update(instructions_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-instructions", partial: "agents/show_instructions", locals: { agent: @agent }) }
        format.html { redirect_to @agent, notice: "Instructions updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-instructions", partial: "agents/show_instructions", locals: { agent: @agent }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def update_config
    attrs = config_params

    unless parse_config_json(attrs)
      render_invalid_config_json
      return
    end

    if @agent.update(attrs)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-config", partial: "agents/show_config", locals: { agent: @agent }) }
        format.html { redirect_to @agent, notice: "Configuration updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-config", partial: "agents/show_config", locals: { agent: @agent }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def update_settings
    if @agent.update(settings_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-settings", partial: "agents/show_settings", locals: { agent: @agent }) }
        format.html { redirect_to @agent, notice: "Settings updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-settings", partial: "agents/show_settings", locals: { agent: @agent }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def archive
    if @agent.archived?
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-settings", partial: "agents/show_settings", locals: { agent: @agent }), status: :unprocessable_entity }
        format.html { redirect_to @agent, alert: "Agent is already archived" }
      end
      return
    end

    @agent.archive!(current_user)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("panel-settings", partial: "agents/show_settings", locals: { agent: @agent }),
          turbo_stream.replace("agent_show_summary_#{@agent.id}", partial: "agents/show_summary", locals: { agent: @agent, health_stats: {} })
        ]
      end
      format.html { redirect_to @agent, notice: "Agent archived" }
    end
  end

  def restore
    unless @agent.archived?
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-settings", partial: "agents/show_settings", locals: { agent: @agent }), status: :unprocessable_entity }
        format.html { redirect_to @agent, alert: "Agent is not archived" }
      end
      return
    end

    @agent.restore!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("panel-settings", partial: "agents/show_settings", locals: { agent: @agent }),
          turbo_stream.replace("agent_show_summary_#{@agent.id}", partial: "agents/show_summary", locals: { agent: @agent, health_stats: {} })
        ]
      end
      format.html { redirect_to @agent, notice: "Agent restored" }
    end
  end

  def assign_skill
    skill = current_user.skills.find(params[:skill_id])
    @agent.agent_skills.create!(skill: skill)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-skills", partial: "agents/show_skills", locals: { agent: @agent, available_skills: @agent.user.skills.where.not(id: @agent.skill_ids).order(:name) }) }
      format.html { redirect_to agent_path(@agent), notice: "Skill assigned" }
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_to agent_path(@agent), alert: e.message }
    end
  end

  def remove_skill
    agent_skill = @agent.agent_skills.find_by!(skill_id: params[:skill_id])
    agent_skill.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-skills", partial: "agents/show_skills", locals: { agent: @agent, available_skills: @agent.user.skills.where.not(id: @agent.skill_ids).order(:name) }) }
      format.html { redirect_to agent_path(@agent), notice: "Skill removed" }
    end
  end

  private

  def set_agent
    @agent = current_user.agents.find(params[:id])
  end

  def require_owner_user!
    @agent = Agent.find(params[:id])
    unless @agent.user_id == current_user.id
      redirect_to agents_path, alert: "Not authorized"
    end
  end

  def instructions_params
    params.require(:agent).permit(:instructions, :custom_instructions)
  end

  def config_params
    params.require(:agent).permit(:model, :max_concurrent_tasks, :custom_env, :custom_args)
  end

  def settings_params
    params.require(:agent).permit(:status)
  end

  def parse_config_json(attrs)
    %i[custom_env custom_args].each do |key|
      val = attrs[key]
      next if val.nil?

      attrs[key] = case val
      when Hash, Array then val
      when String
        stripped = val.strip
        if stripped.empty?
          key == :custom_env ? {} : []
        else
          JSON.parse(stripped)
        end
      else key == :custom_env ? {} : []
      end
    end
    true
  rescue JSON::ParserError
    @agent.errors.add(:base, "Invalid JSON format in configuration fields")
    false
  end

  def render_invalid_config_json
    flash.now[:alert] = "Invalid JSON format in configuration fields"

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("panel-config", partial: "agents/show_config", locals: { agent: @agent }), status: :unprocessable_entity }
      format.html { render :show, status: :unprocessable_entity }
    end
  end
end
