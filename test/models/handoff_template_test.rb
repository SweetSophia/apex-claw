require "test_helper"

class HandoffTemplateTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = Board.create!(user: @user, name: "Test Board")
    @agent = Agent.create!(user: @user, name: "Test Agent", hostname: "test.local", host_uid: "uid-test", platform: "linux", status: :online)
  end

  test "requires name" do
    template = HandoffTemplate.new(user: @user, agent: @agent, name: nil, context_template: "Context")

    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
  end

  test "requires context template" do
    template = HandoffTemplate.new(user: @user, agent: @agent, name: "Template", context_template: nil)

    assert_not template.valid?
    assert_includes template.errors[:context_template], "can't be blank"
  end

  test "validates name uniqueness scoped to user id" do
    HandoffTemplate.create!(user: @user, agent: @agent, name: "Shared Name", context_template: "First")

    duplicate = HandoffTemplate.new(user: @user, agent: @agent, name: "Shared Name", context_template: "Second")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists in your workspace"
  end

  test "belongs to user" do
    template = HandoffTemplate.create!(user: @user, agent: @agent, name: "User Template", context_template: "Context")

    assert_equal @user, template.user
  end

  test "belongs to agent when present" do
    template = HandoffTemplate.create!(user: @user, agent: @agent, name: "Agent Template", context_template: "Context")

    assert_equal @agent, template.agent
  end

  test "agent is optional" do
    template = HandoffTemplate.create!(user: @user, name: "No Agent", context_template: "Context")

    assert_nil template.agent
  end

  test "auto suggest defaults to false" do
    template = HandoffTemplate.create!(user: @user, agent: @agent, name: "Default Auto Suggest", context_template: "Context")

    assert_equal false, template.auto_suggest
  end

  test "render context replaces placeholders with task values" do
    task = Task.create!(
      user: @user,
      board: @board,
      name: "Blocked Task",
      description: "Investigate the deploy failure",
      priority: :high,
      status: :in_progress,
      tags: [ "backend", "urgent" ]
    )
    template = HandoffTemplate.create!(
      user: @user,
      agent: @agent,
      name: "Render Template",
      context_template: "Task: {{task_name}} | Description: {{task_description}} | Priority: {{task_priority}} | Status: {{task_status}} | Tags: {{task_tags}} | From: {{from_agent}}"
    )

    rendered = template.render_context(task: task, from_agent: @agent)

    assert_equal "Task: Blocked Task | Description: Investigate the deploy failure | Priority: high | Status: in_progress | Tags: backend, urgent | From: Test Agent", rendered
  end

  test "render context returns raw template when no task given" do
    template = HandoffTemplate.create!(
      user: @user,
      agent: @agent,
      name: "Raw Template",
      context_template: "Task: {{task_name}} | Description: {{task_description}}"
    )

    assert_equal "Task: {{task_name}} | Description: {{task_description}}", template.render_context
  end
end
