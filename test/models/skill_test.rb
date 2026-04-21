require "test_helper"

class SkillTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  # Validations
  test "requires name" do
    skill = Skill.new(user: @user, name: nil)
    assert_not skill.valid?
    assert_includes skill.errors[:name], "can't be blank"
  end

  test "valid with required attributes" do
    skill = Skill.new(user: @user, name: "Code Review")
    assert skill.valid?
  end

  test "name uniqueness scoped to user" do
    Skill.create!(user: @user, name: "Testing")
    second = Skill.new(user: @user, name: "Testing")
    assert_not second.valid?
    assert_includes second.errors[:name], "already exists in your workspace"

    other_user = users(:two)
    other = Skill.new(user: other_user, name: "Testing")
    assert other.valid?
  end

  test "body length validation" do
    skill = Skill.new(user: @user, name: "Long Skill", body: "x" * 65_536)
    assert_not skill.valid?
    assert_includes skill.errors[:body], "is too long (maximum is 65535 characters)"
  end

  # Associations
  test "belongs to user" do
    skill = Skill.create!(user: @user, name: "My Skill")
    assert_equal @user, skill.user
  end

  test "has many agent_skills" do
    skill = Skill.create!(user: @user, name: "Agent Skill Test")
    agent = Agent.create!(user: @user, name: "Agent", hostname: "test.local", host_uid: "uid", platform: "linux")
    skill.agent_skills.create!(agent: agent)

    assert_equal 1, skill.agent_skills.count
  end

  test "has many agents through agent_skills" do
    skill = Skill.create!(user: @user, name: "Through Test")
    agent1 = Agent.create!(user: @user, name: "Agent 1", hostname: "a1.local", host_uid: "uid1", platform: "linux")
    agent2 = Agent.create!(user: @user, name: "Agent 2", hostname: "a2.local", host_uid: "uid2", platform: "linux")
    skill.agent_skills.create!(agent: agent1)
    skill.agent_skills.create!(agent: agent2)

    assert_equal 2, skill.agents.count
    assert_includes skill.agents, agent1
    assert_includes skill.agents, agent2
  end

  # Scopes
  test "recent scope orders by created_at desc" do
    older = Skill.create!(user: @user, name: "Older")
    newer = Skill.create!(user: @user, name: "Newer")
    assert_equal [newer, older], Skill.recent.to_a
  end

  # Methods
  test "assigned_to_agent?" do
    skill = Skill.create!(user: @user, name: "Assign Check")
    agent = Agent.create!(user: @user, name: "Agent", hostname: "assign.local", host_uid: "uid", platform: "linux")

    assert_not skill.assigned_to_agent?(agent)

    skill.agent_skills.create!(agent: agent)
    assert skill.reload.assigned_to_agent?(agent)
  end
end
