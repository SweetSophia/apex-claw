module AgentCommands
  class PresetEnqueuer
    def initialize(agent:, requested_by_user:)
      @agent = agent
      @requested_by_user = requested_by_user
    end

    def enqueue!(preset)
      raise ActiveRecord::RecordInvalid, preset unless preset.applicable_to?(agent)

      agent.agent_commands.create!(
        kind: preset.kind,
        payload: preset.payload || {},
        requested_by_user: requested_by_user,
        command_preset: preset
      )
    end

    private

    attr_reader :agent, :requested_by_user
  end
end
