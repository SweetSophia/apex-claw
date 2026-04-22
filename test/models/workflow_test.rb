require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @agent = Agent.create!(user: @user, name: "Workflow Agent", hostname: "wf.local", host_uid: "uid-wf", platform: "linux", status: :online)
  end

  # Validations
  test "requires name" do
    workflow = Workflow.new(user: @user, agent: @agent, name: nil)
    assert_not workflow.valid?
    assert_includes workflow.errors[:name], "can't be blank"
  end

  test "valid with required attributes" do
    workflow = Workflow.new(user: @user, agent: @agent, name: "Test Workflow")
    assert workflow.valid?
  end

  # Associations
  test "belongs to user" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Assoc Test")
    assert_equal @user, workflow.user
  end

  test "belongs to agent" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Agent Test")
    assert_equal @agent, workflow.agent
  end

  test "has many workflow_runs" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Runs Test")
    workflow.workflow_runs.create!(user: @user, trigger_type: :manual)
    workflow.workflow_runs.create!(user: @user, trigger_type: :schedule)
    assert_equal 2, workflow.workflow_runs.count
  end

  # Enums
  test "trigger types" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Trigger Test")
    assert workflow.manual?
    workflow.schedule!
    assert workflow.schedule?
  end

  test "execution modes" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Mode Test")
    assert workflow.create_task?
    workflow.run_only!
    assert workflow.run_only?
  end

  test "statuses" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Status Test")
    assert workflow.active?
    workflow.paused!
    assert workflow.paused?
    workflow.archived!
    assert workflow.archived?
  end

  # Scopes
  test "active scope" do
    active_wf = Workflow.create!(user: @user, agent: @agent, name: "Active")
    paused_wf = Workflow.create!(user: @user, agent: @agent, name: "Paused", status: :paused)
    assert_includes Workflow.active, active_wf
    refute_includes Workflow.active, paused_wf
  end

  # Methods
  test "trigger! creates a pending run" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Trigger!")
    run = workflow.trigger!(trigger_type: :manual)
    assert run.persisted?
    assert run.pending?
    assert_equal "manual", run.trigger_type
  end

  test "trigger! returns false when paused" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Paused WF", status: :paused)
    run = workflow.trigger!
    assert_equal false, run
  end

  test "runnable? returns true for active workflow with non-archived agent" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Runnable")
    assert workflow.runnable?
  end

  test "runnable? returns false for paused workflow" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Not Runnable", status: :paused)
    assert_not workflow.runnable?
  end

  test "runnable? returns false with archived agent" do
    @agent.update!(archived_at: Time.current, archived_by: @user)
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Archived Agent WF")
    assert_not workflow.runnable?
  end

  # Cross-user isolation
  test "rejects agent belonging to different user" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other.local", host_uid: "uid-other", platform: "linux")
    workflow = Workflow.new(user: @user, agent: other_agent, name: "Cross-User WF")
    assert_not workflow.valid?
    assert_includes workflow.errors[:agent_id], "must belong to you"
  end
end
