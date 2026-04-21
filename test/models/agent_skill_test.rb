require "test_helper"

class AgentSkillTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @agent = Agent.create!(user: @user, name: "Skill Agent", hostname: "skill.local", host_uid: "uid", platform: "linux")
    @skill = Skill.create!(user: @user, name: "Test Skill")
  end

  test "valid with agent and skill" do
    agent_skill = AgentSkill.new(agent: @agent, skill: @skill)
    assert agent_skill.valid?
  end

  test "unique agent-skill combination" do
    AgentSkill.create!(agent: @agent, skill: @skill)
    second = AgentSkill.new(agent: @agent, skill: @skill)
    assert_not second.valid?
    assert_includes second.errors[:agent_id], "already has this skill"
  end

  test "skill must belong to same workspace as agent" do
    other_user = users(:two)
    other_skill = Skill.create!(user: other_user, name: "Other Skill")

    agent_skill = AgentSkill.new(agent: @agent, skill: other_skill)
    assert_not agent_skill.valid?
    assert_includes agent_skill.errors[:skill], "must belong to the same workspace"
  end

  test "same skill can be assigned to different agents" do
    AgentSkill.create!(agent: @agent, skill: @skill)
    other_agent = Agent.create!(user: @user, name: "Other Agent", hostname: "other.local", host_uid: "uid2", platform: "linux")

    other = AgentSkill.new(agent: other_agent, skill: @skill)
    assert other.valid?
  end
end
