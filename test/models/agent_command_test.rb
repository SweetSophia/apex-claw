require "test_helper"

class AgentCommandTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @agent = Agent.create!(user: @user, name: "Command Agent")
  end

  # Validations
  test "requires kind" do
    command = AgentCommand.new(agent: @agent, kind: nil)
    assert_not command.valid?
    assert_includes command.errors[:kind], "can't be blank"
  end

  test "valid with required attributes" do
    command = AgentCommand.new(agent: @agent, kind: "drain")
    assert command.valid?
  end

  # Associations
  test "belongs to agent" do
    command = @agent.agent_commands.create!(kind: "drain", payload: {})
    assert_equal @agent, command.agent
  end

  test "belongs to requested_by_user optionally" do
    command = @agent.agent_commands.create!(kind: "drain", payload: {}, requested_by_user: @user)
    assert_equal @user, command.requested_by_user
  end

  test "requested_by_user is optional" do
    command = @agent.agent_commands.create!(kind: "drain", payload: {})
    assert_nil command.requested_by_user
  end

  # Enum: state
  test "default state is pending" do
    command = @agent.agent_commands.create!(kind: "drain", payload: {})
    assert_equal "pending", command.state
  end

  test "can transition to acknowledged" do
    command = @agent.agent_commands.create!(kind: "drain", payload: {})
    command.update!(state: :acknowledged, acked_at: Time.current)
    assert_equal "acknowledged", command.state
  end

  test "can transition to completed" do
    command = @agent.agent_commands.create!(kind: "drain", payload: {}, state: :acknowledged, acked_at: Time.current)
    command.update!(state: :completed, completed_at: Time.current)
    assert_equal "completed", command.state
  end

  test "can transition to failed" do
    command = @agent.agent_commands.create!(kind: "drain", payload: {}, state: :acknowledged, acked_at: Time.current)
    command.update!(state: :failed)
    assert_equal "failed", command.state
  end

  # Scopes
  test "for_agent scope filters by agent" do
    other_agent = Agent.create!(user: @user, name: "Other Agent")
    cmd1 = @agent.agent_commands.create!(kind: "drain", payload: {})
    cmd2 = other_agent.agent_commands.create!(kind: "restart", payload: {})

    results = AgentCommand.for_agent(@agent)
    assert_includes results, cmd1
    assert_not_includes results, cmd2
  end

  test "pending_for scope returns only pending commands for agent" do
    pending = @agent.agent_commands.create!(kind: "drain", payload: {})
    acked = @agent.agent_commands.create!(kind: "drain", payload: {}, state: :acknowledged, acked_at: Time.current)

    results = AgentCommand.pending_for(@agent)
    assert_includes results, pending
    assert_not_includes results, acked
  end

  # Payload
  test "payload defaults to empty hash" do
    command = @agent.agent_commands.create!(kind: "drain")
    assert_equal({}, command.payload)
  end

  test "payload stores arbitrary JSON" do
    command = @agent.agent_commands.create!(
      kind: "upgrade",
      payload: { version: "2.0.0", force: true, notes: "Major release" }
    )
    command.reload
    assert_equal "2.0.0", command.payload["version"]
    assert_equal true, command.payload["force"]
  end
end
