require "test_helper"

class RoutingRules::EvaluatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = Board.create!(user: @user, name: "Test Board")
    @agent1 = Agent.create!(user: @user, name: "Agent 1", hostname: "a1.local", host_uid: "uid-a1", platform: "linux", status: :online)
    @agent2 = Agent.create!(user: @user, name: "Agent 2", hostname: "a2.local", host_uid: "uid-a2", platform: "linux", status: :online)
  end

  test "returns nil when task already has assigned agent" do
    task = create_task(assigned_agent: @agent1)
    RoutingRule.create!(user: @user, agent: @agent2, name: "Match", priority: 10, conditions: { "status" => "inbox" })

    result = RoutingRules::Evaluator.new(task).evaluate_and_assign!

    assert_nil result
    assert_equal @agent1, task.reload.assigned_agent
  end

  test "returns nil when no rules match" do
    task = create_task(priority: :low)
    RoutingRule.create!(user: @user, agent: @agent1, name: "High Priority", conditions: { "priority" => "high" })

    result = RoutingRules::Evaluator.new(task).evaluate_and_assign!

    assert_nil result
    assert_nil task.reload.assigned_agent
  end

  test "returns matching rule and assigns agent" do
    task = create_task(priority: :high)
    rule = RoutingRule.create!(user: @user, agent: @agent1, name: "High Priority", priority: 5, conditions: { "priority" => "high" })

    result = RoutingRules::Evaluator.new(task).evaluate_and_assign!

    assert_equal rule, result
    assert_equal @agent1, task.reload.assigned_agent
    assert task.assigned_to_agent
  end

  test "picks highest priority rule when multiple match" do
    task = create_task(status: :inbox)
    low_rule = RoutingRule.create!(user: @user, agent: @agent1, name: "Low Priority", priority: 1, conditions: { "status" => "inbox" })
    high_rule = RoutingRule.create!(user: @user, agent: @agent2, name: "High Priority", priority: 10, conditions: { "status" => "inbox" })

    result = RoutingRules::Evaluator.new(task).evaluate_and_assign!

    assert_equal high_rule, result
    assert_equal @agent2, task.reload.assigned_agent
    assert_not_equal low_rule, result
  end

  test "skips rules with inactive agents" do
    task = create_task(status: :inbox)
    inactive_agent = Agent.create!(user: @user, name: "Inactive Agent", hostname: "inactive.local", host_uid: "uid-inactive", platform: "linux", status: :offline)
    RoutingRule.create!(user: @user, agent: inactive_agent, name: "Inactive Rule", priority: 10, conditions: { "status" => "inbox" })
    active_rule = RoutingRule.create!(user: @user, agent: @agent1, name: "Active Rule", priority: 5, conditions: { "status" => "inbox" })

    result = RoutingRules::Evaluator.new(task).evaluate_and_assign!

    assert_equal active_rule, result
    assert_equal @agent1, task.reload.assigned_agent
  end

  test "skips inactive rules" do
    task = create_task(status: :inbox)
    RoutingRule.create!(user: @user, agent: @agent2, name: "Inactive Rule", priority: 10, active: false, conditions: { "status" => "inbox" })
    active_rule = RoutingRule.create!(user: @user, agent: @agent1, name: "Active Rule", priority: 5, conditions: { "status" => "inbox" })

    result = RoutingRules::Evaluator.new(task).evaluate_and_assign!

    assert_equal active_rule, result
    assert_equal @agent1, task.reload.assigned_agent
  end

  test "evaluates via class method" do
    task = create_task(priority: :high)
    rule = RoutingRule.create!(user: @user, agent: @agent2, name: "Class Method Rule", priority: 7, conditions: { "priority" => "high" })

    result = RoutingRules::Evaluator.evaluate(task)

    assert_equal rule, result
    assert_equal @agent2, task.reload.assigned_agent
  end

  private

  def create_task(priority: :none, status: :inbox, assigned_agent: nil)
    Task.create!(
      user: @user,
      board: @board,
      name: "Routing Task #{SecureRandom.hex(4)}",
      priority: priority,
      status: status,
      assigned_agent: assigned_agent
    )
  end
end
