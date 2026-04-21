require "test_helper"

class TaskHandoffs::EscalatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = Board.create!(user: @user, name: "Test Board")
    @agent1 = Agent.create!(user: @user, name: "Agent 1", hostname: "a1.local", host_uid: "uid-a1", platform: "linux", status: :online)
    @agent2 = Agent.create!(user: @user, name: "Agent 2", hostname: "a2.local", host_uid: "uid-a2", platform: "linux", status: :online)
  end

  test "does nothing when no blocked tasks" do
    assert_difference "TaskHandoff.count", 0 do
      assert_equal 0, TaskHandoffs::Escalator.new.run
    end
  end

  test "skips tasks without escalation enabled" do
    create_blocked_task(escalation_config: { enabled: false, block_timeout_minutes: 30, target_agent_id: @agent2.id }, age_minutes: 31)

    assert_difference "TaskHandoff.count", 0 do
      assert_equal 0, TaskHandoffs::Escalator.new.run
    end
  end

  test "skips tasks where timeout has not elapsed" do
    create_blocked_task(escalation_config: { enabled: true, block_timeout_minutes: 30, target_agent_id: @agent2.id })

    assert_difference "TaskHandoff.count", 0 do
      assert_equal 0, TaskHandoffs::Escalator.new.run
    end
  end

  test "skips tasks with max escalations exceeded" do
    task = create_blocked_task(escalation_config: { enabled: true, block_timeout_minutes: 30, max_escalations: 1, target_agent_id: @agent2.id }, age_minutes: 31)
    task.handoffs.create!(from_agent: @agent1, to_agent: @agent2, context: "Already escalated", escalation: true, reason: "prior escalation", status: :accepted)

    assert_difference "TaskHandoff.count", 0 do
      assert_equal 0, TaskHandoffs::Escalator.new.run
    end
  end

  test "skips tasks that already have pending handoff" do
    task = create_blocked_task(escalation_config: { enabled: true, block_timeout_minutes: 30, target_agent_id: @agent2.id }, age_minutes: 31)
    task.handoffs.create!(from_agent: @agent1, to_agent: @agent2, context: "Pending handoff", reason: "manual")

    assert_difference "TaskHandoff.count", 0 do
      assert_equal 0, TaskHandoffs::Escalator.new.run
    end
  end

  test "creates escalation handoff for eligible task" do
    task = create_blocked_task(escalation_config: { enabled: true, block_timeout_minutes: 30 }, age_minutes: 31)

    with_stubbed_suggester(@agent2) do
      assert_difference "TaskHandoff.count", 1 do
        assert_equal 1, TaskHandoffs::Escalator.new.run
      end
    end

    handoff = task.handoffs.order(:created_at).last
    assert handoff.escalation
    assert_equal @agent1, handoff.from_agent
    assert_equal @agent2, handoff.to_agent
    assert_equal "auto-escalated", handoff.reason
  end

  test "uses configured target agent id when available" do
    task = create_blocked_task(escalation_config: { enabled: true, block_timeout_minutes: 30, target_agent_id: @agent2.id }, age_minutes: 31)

    assert_difference "TaskHandoff.count", 1 do
      assert_equal 1, TaskHandoffs::Escalator.new.run
    end

    assert_equal @agent2, task.handoffs.order(:created_at).last.to_agent
  end

  test "falls back to suggester when no configured target" do
    task = create_blocked_task(escalation_config: { enabled: true, block_timeout_minutes: 30 }, age_minutes: 31)

    with_stubbed_suggester(@agent2) do
      assert_difference "TaskHandoff.count", 1 do
        assert_equal 1, TaskHandoffs::Escalator.new.run
      end
    end

    assert_equal @agent2, task.handoffs.order(:created_at).last.to_agent
  end

  test "respects max escalations config" do
    task = create_blocked_task(escalation_config: { enabled: true, block_timeout_minutes: 30, max_escalations: 2, target_agent_id: @agent2.id }, age_minutes: 31)
    task.handoffs.create!(from_agent: @agent1, to_agent: @agent2, context: "Escalation 1", escalation: true, reason: "first", status: :accepted)
    task.handoffs.create!(from_agent: @agent1, to_agent: @agent2, context: "Escalation 2", escalation: true, reason: "second", status: :accepted)

    assert_difference "TaskHandoff.count", 0 do
      assert_equal 0, TaskHandoffs::Escalator.new.run
    end
  end

  test "uses message template for context" do
    task = create_blocked_task(
      escalation_config: {
        enabled: true,
        block_timeout_minutes: 45,
        target_agent_id: @agent2.id,
        message_template: "Blocked for {{timeout}} minutes"
      },
      age_minutes: 46
    )

    assert_difference "TaskHandoff.count", 1 do
      assert_equal 1, TaskHandoffs::Escalator.new.run
    end

    assert_equal "Blocked for 45 minutes", task.handoffs.order(:created_at).last.context
  end

  private

  def create_blocked_task(escalation_config:, age_minutes: nil)
    task = Task.create!(
      user: @user,
      board: @board,
      name: "Blocked Task #{SecureRandom.hex(4)}",
      blocked: true,
      assigned_agent: @agent1,
      claimed_by_agent: @agent1,
      escalation_config: escalation_config
    )

    return task unless age_minutes

    task.update_columns(created_at: age_minutes.minutes.ago, updated_at: age_minutes.minutes.ago)
    task.reload
  end

  def with_stubbed_suggester(*agents)
    suggestions = agents.map { |agent| { agent: agent } }
    fake_suggester = Object.new
    fake_suggester.define_singleton_method(:suggest) do |limit:|
      suggestions.first(limit)
    end

    TaskHandoffs::Suggester.stub(:new, fake_suggester) do
      yield
    end
  end
end
