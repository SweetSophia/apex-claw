require "test_helper"

class AgentCommandsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @agent = Agent.create!(
      user: @user,
      name: "Web Command Agent",
      hostname: "web-command.local",
      host_uid: "web-command-001",
      platform: "linux",
      version: "1.0.0",
      status: :online
    )
  end

  test "queues preset command through web controller" do
    preset = CommandPreset.create!(user: @user, agent: @agent, name: "Restart Preset", kind: "restart")

    assert_difference "AgentCommand.count", 1 do
      post agent_commands_path(@agent), params: { preset_id: preset.id }
    end

    assert_redirected_to agent_path(@agent)
    assert_equal "Restart command queued.", flash[:notice]
  end

  test "rejects preset scoped to another agent with friendly error" do
    other_agent = Agent.create!(
      user: @user,
      name: "Other Agent",
      hostname: "other-command.local",
      host_uid: "other-command-001",
      platform: "linux",
      version: "1.0.0",
      status: :online
    )
    preset = CommandPreset.create!(user: @user, agent: other_agent, name: "Drain Other", kind: "drain")

    assert_no_difference "AgentCommand.count" do
      post agent_commands_path(@agent), params: { preset_id: preset.id }
    end

    assert_redirected_to agent_path(@agent)
    assert_equal "Failed to queue command: Preset is not applicable to this agent", flash[:alert]
  end

  test "rejects invalid payload json with friendly error" do
    assert_no_difference "AgentCommand.count" do
      post agent_commands_path(@agent), params: { agent_command: { kind: "config_reload", payload: "{bad-json" } }
    end

    assert_redirected_to agent_path(@agent)
    assert_equal "Failed to queue command: Payload must be valid JSON.", flash[:alert]
  end
end
