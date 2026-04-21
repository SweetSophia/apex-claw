require "test_helper"

class CommandPresetTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @agent = create_agent(user: @user, suffix: "primary")
    @other_agent = create_agent(user: @user, suffix: "secondary")
    @foreign_agent = create_agent(user: @other_user, suffix: "foreign")
  end

  test "requires name" do
    preset = CommandPreset.new(user: @user, kind: "drain", name: nil)

    assert_not preset.valid?
    assert_includes preset.errors[:name], "can't be blank"
  end

  test "kind must be in allowed kinds" do
    preset = CommandPreset.new(user: @user, name: "Bad Preset", kind: "upgrade")

    assert_not preset.valid?
    assert_includes preset.errors[:kind], "is not included in the list"
  end

  test "name uniqueness is scoped to user" do
    CommandPreset.create!(user: @user, name: "Maintenance", kind: "drain")

    duplicate = CommandPreset.new(user: @user, name: "Maintenance", kind: "restart")
    other_user_preset = CommandPreset.new(user: @other_user, name: "Maintenance", kind: "restart")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists in your workspace"
    assert other_user_preset.valid?
  end

  test "agent is optional" do
    preset = CommandPreset.new(user: @user, name: "Global Restart", kind: "restart")

    assert preset.valid?
  end

  test "agent must belong to user" do
    preset = CommandPreset.new(user: @user, agent: @foreign_agent, name: "Foreign Agent", kind: "drain")

    assert_not preset.valid?
    assert_includes preset.errors[:agent_id], "must belong to you"
  end

  test "active scope returns active presets only" do
    active = CommandPreset.create!(user: @user, name: "Active", kind: "restart", active: true)
    inactive = CommandPreset.create!(user: @user, name: "Inactive", kind: "restart", active: false)

    assert_includes CommandPreset.active, active
    assert_not_includes CommandPreset.active, inactive
  end

  test "for_agent returns global and matching scoped presets" do
    global = CommandPreset.create!(user: @user, name: "Global", kind: "restart")
    matching = CommandPreset.create!(user: @user, agent: @agent, name: "Scoped", kind: "drain")
    non_matching = CommandPreset.create!(user: @user, agent: @other_agent, name: "Other Agent", kind: "resume")
    other_user_global = CommandPreset.create!(user: @other_user, name: "Other User", kind: "health_check")

    results = @user.command_presets.for_agent(@agent)

    assert_includes results, global
    assert_includes results, matching
    assert_not_includes results, non_matching
    assert_not_includes results, other_user_global
  end

  test "applicable_to? handles global scoped wrong agent and wrong user" do
    global = CommandPreset.create!(user: @user, name: "Global", kind: "restart")
    scoped = CommandPreset.create!(user: @user, agent: @agent, name: "Scoped", kind: "drain")

    assert global.applicable_to?(@agent)
    assert global.applicable_to?(@other_agent)
    assert scoped.applicable_to?(@agent)
    assert_not scoped.applicable_to?(@other_agent)
    assert_not global.applicable_to?(@foreign_agent)
  end

  private

  def create_agent(user:, suffix:)
    Agent.create!(
      user: user,
      name: "Agent #{suffix}",
      hostname: "#{suffix}.example.test",
      host_uid: "uid-#{suffix}",
      platform: "linux",
      version: "1.0.0"
    )
  end
end
