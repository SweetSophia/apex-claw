require "test_helper"

class RoutingRuleTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = Board.create!(user: @user, name: "Test Board")
    @agent = Agent.create!(user: @user, name: "Test Agent", hostname: "test.local", host_uid: "uid-test", platform: "linux", status: :online)
  end

  test "requires name" do
    rule = RoutingRule.new(user: @user, agent: @agent, name: nil, conditions: { "status" => "inbox" })

    assert_not rule.valid?
    assert_includes rule.errors[:name], "can't be blank"
  end

  test "requires conditions" do
    rule = RoutingRule.new(user: @user, agent: @agent, name: "Missing Conditions", conditions: {})

    assert_not rule.valid?
    assert_includes rule.errors[:conditions], "can't be blank"
  end

  test "validates agent belongs to user" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other.local", host_uid: "uid-other", platform: "linux", status: :online)
    rule = RoutingRule.new(user: @user, agent: other_agent, name: "Cross User", conditions: { "status" => "inbox" })

    assert_not rule.valid?
    assert_includes rule.errors[:agent_id], "must belong to you"
  end

  test "validates conditions schema rejects invalid keys" do
    rule = RoutingRule.new(user: @user, agent: @agent, name: "Bad Keys", conditions: { "unknown" => "value" })

    assert_not rule.valid?
    assert_includes rule.errors[:conditions].join(", "), "contains invalid keys"
  end

  test "validates conditions schema rejects invalid priority" do
    rule = RoutingRule.new(user: @user, agent: @agent, name: "Bad Priority", conditions: { "priority" => "urgent" })

    assert_not rule.valid?
    assert_includes rule.errors[:conditions].join(", "), "has invalid priority"
  end

  test "validates conditions schema rejects invalid status" do
    rule = RoutingRule.new(user: @user, agent: @agent, name: "Bad Status", conditions: { "status" => "blocked" })

    assert_not rule.valid?
    assert_includes rule.errors[:conditions].join(", "), "has invalid status"
  end

  test "matches returns true for empty conditions" do
    task = create_task
    rule = RoutingRule.new(user: @user, agent: @agent, name: "Empty Conditions", conditions: {}, active: true)

    assert rule.matches?(task)
  end

  test "matches checks skills overlap" do
    task = create_task
    rule = RoutingRule.create!(user: @user, agent: @agent, name: "Skill Match", conditions: { "skills" => [ "Ruby", "Rails" ] })

    matches = task.stub(:required_skills, [ "Ruby" ]) do
      rule.matches?(task)
    end

    assert matches
  end

  test "matches checks priority equality" do
    task = create_task(priority: :high)
    rule = RoutingRule.create!(user: @user, agent: @agent, name: "Priority Match", conditions: { "priority" => "high" })

    assert rule.matches?(task)
  end

  test "matches checks tag overlap" do
    task = create_task(tags: [ "backend", "ops" ])
    rule = RoutingRule.create!(user: @user, agent: @agent, name: "Tag Match", conditions: { "tags" => [ "frontend", "backend" ] })

    assert rule.matches?(task)
  end

  test "matches checks status equality" do
    task = create_task(status: :in_review)
    rule = RoutingRule.create!(user: @user, agent: @agent, name: "Status Match", conditions: { "status" => "in_review" })

    assert rule.matches?(task)
  end

  test "matches returns false when conditions do not match" do
    task = create_task(priority: :low, status: :inbox, tags: [ "frontend" ])
    rule = RoutingRule.create!(
      user: @user,
      agent: @agent,
      name: "No Match",
      conditions: {
        "skills" => [ "Ruby" ],
        "priority" => "high",
        "tags" => [ "backend" ],
        "status" => "done"
      }
    )

    matches = task.stub(:required_skills, [ "Python" ]) do
      rule.matches?(task)
    end

    assert_not matches
  end

  test "active scope filters correctly" do
    active_rule = RoutingRule.create!(user: @user, agent: @agent, name: "Active Rule", conditions: { "status" => "inbox" }, active: true)
    inactive_rule = RoutingRule.create!(user: @user, agent: @agent, name: "Inactive Rule", conditions: { "status" => "inbox" }, active: false)

    assert RoutingRule.active.include?(active_rule)
    assert_not RoutingRule.active.include?(inactive_rule)
  end

  test "by priority orders correctly" do
    low_rule = RoutingRule.create!(user: @user, agent: @agent, name: "Low", priority: 1, conditions: { "status" => "inbox" })
    medium_rule = RoutingRule.create!(user: @user, agent: @agent, name: "Medium", priority: 5, conditions: { "status" => "inbox" })
    high_rule = RoutingRule.create!(user: @user, agent: @agent, name: "High", priority: 10, conditions: { "status" => "inbox" })

    assert_equal [ high_rule, medium_rule, low_rule ], RoutingRule.where(id: [ low_rule.id, medium_rule.id, high_rule.id ]).by_priority.to_a
  end

  private

  def create_task(priority: :none, status: :inbox, tags: [])
    Task.create!(
      user: @user,
      board: @board,
      name: "Routing Task #{SecureRandom.hex(4)}",
      priority: priority,
      status: status,
      tags: tags
    )
  end
end
