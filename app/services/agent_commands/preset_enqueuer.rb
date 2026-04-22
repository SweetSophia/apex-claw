module AgentCommands
  class PresetEnqueuer
    def initialize(agent:, requested_by_user:)
      @agent = agent
      @requested_by_user = requested_by_user
    end

    def enqueue!(preset)
      unless preset.applicable_to?(agent)
        preset.errors.add(:base, "Preset is not applicable to this agent")
        raise ActiveRecord::RecordInvalid, preset
      end

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
