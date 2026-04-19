require "test_helper"

class AgentTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

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

  test "heartbeat_stale? is true when never connected" do
    agent = Agent.create!(user: @user, name: "No Heartbeat")

    assert agent.heartbeat_stale?
  end

  test "health_status is healthy when online with active runner and fresh heartbeat" do
    travel_to Time.current do
      agent = Agent.create!(
        user: @user,
        name: "Healthy Agent",
        status: :online,
        last_heartbeat_at: 2.minutes.ago,
        metadata: { "task_runner_active" => true, "uptime_seconds" => 3600 }
      )

      assert_equal :healthy, agent.health_status
      assert_equal "Healthy", agent.health_badge_label
    end
  end

  test "health_status is degraded when online but runner inactive" do
    travel_to Time.current do
      agent = Agent.create!(
        user: @user,
        name: "Idle Agent",
        status: :online,
        last_heartbeat_at: 1.minute.ago,
        metadata: { "task_runner_active" => false }
      )

      assert_equal :degraded, agent.health_status
    end
  end

  test "health_status is offline when heartbeat is stale" do
    travel_to Time.current do
      agent = Agent.create!(
        user: @user,
        name: "Stale Agent",
        status: :online,
        last_heartbeat_at: 10.minutes.ago,
        metadata: { "task_runner_active" => true }
      )

      assert_equal :offline, agent.health_status
    end
  end

  test "uptime_label is human friendly" do
    agent = Agent.create!(user: @user, name: "Timed Agent", metadata: { "uptime_seconds" => 3660 })

    assert_equal "1h 1m", agent.uptime_label
  end

  test "recent completed task and command metrics are calculated over 24 hours" do
    travel_to Time.current do
      agent = Agent.create!(
        user: @user,
        name: "Metrics Agent",
        status: :online,
        last_heartbeat_at: Time.current,
        metadata: { "task_runner_active" => true }
      )
      board = @user.boards.first || @user.boards.create!(name: "Board", icon: "📋", color: "gray")

      Task.create!(
        user: @user,
        board: board,
        name: "Recent Done",
        claimed_by_agent: agent,
        status: :done,
        completed: true,
        completed_at: 2.hours.ago
      )
      Task.create!(
        user: @user,
        board: board,
        name: "Old Done",
        claimed_by_agent: agent,
        status: :done,
        completed: true,
        completed_at: 3.days.ago
      )

      agent.agent_commands.create!(kind: "restart", payload: {}, state: :completed, created_at: 4.hours.ago)
      agent.agent_commands.create!(kind: "drain", payload: {}, state: :failed, created_at: 3.hours.ago)
      agent.agent_commands.create!(kind: "resume", payload: {}, state: :pending, created_at: 2.days.ago)

      assert_equal 1, agent.recent_completed_tasks_count
      assert_equal 2, agent.recent_commands_count
      assert_equal 1, agent.recent_failed_commands_count
      assert_equal 50, agent.recent_command_error_rate
      assert_equal 1, agent.pending_commands_count
    end
  end

  test "health_stats_for aggregates counts for multiple agents" do
    travel_to Time.current do
      first_agent = Agent.create!(
        user: @user,
        name: "First Metrics Agent",
        status: :online,
        last_heartbeat_at: Time.current,
        metadata: { "task_runner_active" => true }
      )
      second_agent = Agent.create!(
        user: @user,
        name: "Second Metrics Agent",
        status: :online,
        last_heartbeat_at: Time.current,
        metadata: { "task_runner_active" => false }
      )
      board = @user.boards.first || @user.boards.create!(name: "Board", icon: "📋", color: "gray")

      Task.create!(
        user: @user,
        board: board,
        name: "First Recent Done",
        claimed_by_agent: first_agent,
        status: :done,
        completed: true,
        completed_at: 1.hour.ago
      )
      Task.create!(
        user: @user,
        board: board,
        name: "Second Recent Done",
        claimed_by_agent: second_agent,
        status: :done,
        completed: true,
        completed_at: 2.hours.ago
      )

      Task.create!(
        user: @user,
        board: board,
        name: "Assigned Open Task",
        assigned_agent: first_agent,
        status: :up_next,
        completed: false
      )
      Task.create!(
        user: @user,
        board: board,
        name: "Claimed Open Task",
        claimed_by_agent: first_agent,
        status: :in_progress,
        completed: false
      )

      first_agent.agent_commands.create!(kind: "restart", payload: {}, state: :completed, created_at: 4.hours.ago)
      first_agent.agent_commands.create!(kind: "drain", payload: {}, state: :failed, created_at: 3.hours.ago)
      first_agent.agent_commands.create!(kind: "resume", payload: {}, state: :pending, created_at: 2.days.ago)
      second_agent.agent_commands.create!(kind: "restart", payload: {}, state: :pending, created_at: 30.minutes.ago)

      stats = Agent.health_stats_for([ first_agent, second_agent ])

      assert_equal({
        completed: 1,
        commands: 2,
        failed: 1,
        pending: 1,
        claimed_count: 1,
        assigned_count: 1,
        error_rate: 50
      }, stats.fetch(first_agent.id))
      assert_equal({
        completed: 1,
        commands: 1,
        failed: 0,
        pending: 1,
        claimed_count: 0,
        assigned_count: 0,
        error_rate: 0
      }, stats.fetch(second_agent.id))
    end
  end
end
