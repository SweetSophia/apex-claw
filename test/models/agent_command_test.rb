require "test_helper"

class AgentCommandTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:one)
    @agent = create_agent(@user, "command-agent")
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

  test "command_preset association is optional" do
    preset = CommandPreset.create!(user: @user, agent: @agent, name: "Restart Preset", kind: "restart")

    command_without_preset = @agent.agent_commands.create!(kind: "drain", payload: {})
    command_with_preset = @agent.agent_commands.create!(kind: "restart", payload: {}, command_preset: preset)

    assert_nil command_without_preset.command_preset
    assert_equal preset, command_with_preset.command_preset
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
    other_agent = create_agent(@user, "other-agent")
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

  test "kind validation allows health_check and config_reload" do
    %w[health_check config_reload].each do |kind|
      command = AgentCommand.new(agent: @agent, kind: kind)

      assert command.valid?, "expected #{kind} to be valid"
    end
  end

  test "recent scope orders newest first" do
    older = @agent.agent_commands.create!(kind: "drain", payload: {}, created_at: 2.hours.ago)
    newer = @agent.agent_commands.create!(kind: "restart", payload: {}, created_at: 10.minutes.ago)

    assert_equal [ newer, older ], AgentCommand.where(id: [ older.id, newer.id ]).recent.to_a
  end

  test "failed_recent scope returns recent failed commands only" do
    recent_failed = @agent.agent_commands.create!(kind: "drain", payload: {}, state: :failed, created_at: 2.hours.ago)
    @agent.agent_commands.create!(kind: "restart", payload: {}, state: :failed, created_at: 2.days.ago)
    @agent.agent_commands.create!(kind: "resume", payload: {}, state: :completed, created_at: 1.hour.ago)

    results = AgentCommand.failed_recent(6.hours)

    assert_includes results, recent_failed
    assert_equal [ recent_failed ], results.to_a
  end

  test "long_running scope returns acknowledged commands past threshold" do
    long_running = @agent.agent_commands.create!(
      kind: "drain",
      payload: {},
      state: :acknowledged,
      acked_at: 20.minutes.ago
    )
    @agent.agent_commands.create!(kind: "restart", payload: {}, state: :acknowledged, acked_at: 5.minutes.ago)
    @agent.agent_commands.create!(kind: "resume", payload: {}, state: :pending)

    results = AgentCommand.long_running(10.minutes)

    assert_equal [ long_running ], results.to_a
  end

  # Payload
  test "payload defaults to empty hash" do
    command = @agent.agent_commands.create!(kind: "drain")
    assert_equal({}, command.payload)
  end

  test "payload stores arbitrary JSON" do
    command = @agent.agent_commands.create!(
      kind: "config_reload",
      payload: { version: "2.0.0", force: true, notes: "Major release" }
    )
    command.reload
    assert_equal "2.0.0", command.payload["version"]
    assert_equal true, command.payload["force"]
  end

  private

  def create_agent(user, suffix)
    Agent.create!(
      user: user,
      name: suffix.titleize,
      hostname: "#{suffix}.example.test",
      host_uid: "uid-#{suffix}",
      platform: "linux",
      version: "1.0.0"
    )
  end
end
