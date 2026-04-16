require "test_helper"

class AgentTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # Validations
  test "requires name" do
    agent = Agent.new(user: @user, name: nil)
    assert_not agent.valid?
    assert_includes agent.errors[:name], "can't be blank"
  end

  test "valid with required attributes" do
    agent = Agent.new(user: @user, name: "Test Agent")
    assert agent.valid?
  end

  # Associations
  test "belongs to user" do
    agent = Agent.create!(user: @user, name: "Assoc Agent")
    assert_equal @user, agent.user
  end

  test "has many agent tokens" do
    agent = Agent.create!(user: @user, name: "Token Agent")
    first_token, = AgentToken.issue!(agent: agent, name: "T1")
    first_token.update!(revoked_at: Time.current)
    AgentToken.issue!(agent: agent, name: "T2")

    assert_equal 2, agent.agent_tokens.count
  end

  test "has many agent commands" do
    agent = Agent.create!(user: @user, name: "Cmd Agent")
    agent.agent_commands.create!(kind: "drain", payload: {})
    agent.agent_commands.create!(kind: "restart", payload: {})

    assert_equal 2, agent.agent_commands.count
  end

  test "has many assigned tasks" do
    agent = Agent.create!(user: @user, name: "Task Agent")
    board = @user.boards.first || @user.boards.create!(name: "Board", icon: "📋", color: "gray")
    task = Task.create!(user: @user, board: board, name: "Assigned Task", assigned_agent: agent)

    assert_includes agent.assigned_tasks, task
  end

  test "destroys agent tokens on destroy" do
    agent = Agent.create!(user: @user, name: "Destroy Agent")
    first_token, = AgentToken.issue!(agent: agent, name: "T1")
    first_token.update!(revoked_at: Time.current)
    AgentToken.issue!(agent: agent, name: "T2")

    assert_equal 2, agent.agent_tokens.count
    agent.destroy
    assert_equal 0, AgentToken.where(agent_id: agent.id).count
  end

  test "destroys agent commands on destroy" do
    agent = Agent.create!(user: @user, name: "Destroy Agent")
    agent.agent_commands.create!(kind: "drain", payload: {})

    agent.destroy
    assert_equal 0, AgentCommand.where(agent_id: agent.id).count
  end

  test "nullifies assigned tasks on destroy" do
    agent = Agent.create!(user: @user, name: "Nullify Agent")
    board = @user.boards.first || @user.boards.create!(name: "Board", icon: "📋", color: "gray")
    task = Task.create!(user: @user, board: board, name: "Orphaned Task", assigned_agent: agent)

    agent.destroy
    task.reload
    assert_nil task.assigned_agent_id
  end

  # Enum: status
  test "default status is offline" do
    agent = Agent.create!(user: @user, name: "Default Status")
    assert_equal "offline", agent.status
  end

  test "status can be set to online" do
    agent = Agent.create!(user: @user, name: "Online Agent", status: :online)
    assert_equal "online", agent.status
  end

  test "status can be set to draining" do
    agent = Agent.create!(user: @user, name: "Draining Agent", status: :draining)
    assert_equal "draining", agent.status
  end

  test "status can be set to disabled" do
    agent = Agent.create!(user: @user, name: "Disabled Agent", status: :disabled)
    assert_equal "disabled", agent.status
  end

  test "draining? returns true for draining agent" do
    agent = Agent.create!(user: @user, name: "Check Agent", status: :draining)
    assert agent.draining?
  end

  test "draining? returns false for online agent" do
    agent = Agent.create!(user: @user, name: "Check Agent", status: :online)
    assert_not agent.draining?
  end

  # Scopes and helpers
  test "tags default to empty array" do
    agent = Agent.create!(user: @user, name: "No Tags")
    assert_equal [], agent.tags
  end

  test "metadata defaults to empty hash" do
    agent = Agent.create!(user: @user, name: "No Meta")
    assert_equal({}, agent.metadata)
  end
end
