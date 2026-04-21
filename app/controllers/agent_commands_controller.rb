class AgentCommandsController < ApplicationController
  before_action :set_agent

  def create
    @command = if params[:preset_id].present?
      preset = current_user.command_presets.find(params[:preset_id])
      AgentCommands::PresetEnqueuer.new(agent: @agent, requested_by_user: current_user).enqueue!(preset)
    else
      @agent.agent_commands.build(command_params).tap do |command|
        command.requested_by_user = current_user
        command.state = :pending
      end
    end

    if @command.save
      redirect_to agent_path(@agent), notice: "#{@command.kind.humanize} command queued."
    else
      redirect_to agent_path(@agent), alert: "Failed to queue command: #{@command.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_agent
    @agent = current_user.agents.find(params[:agent_id])
  end

  def command_params
    attrs = params.require(:agent_command).permit(:kind, :payload)
    if attrs[:payload].is_a?(String)
      stripped = attrs[:payload].strip
      attrs[:payload] = stripped.present? ? JSON.parse(stripped) : {}
    end
    attrs
  rescue JSON::ParserError
    attrs[:payload] = {}
    attrs
  end
end
