require "test_helper"

class WorkflowRunTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @agent = Agent.create!(user: @user, name: "Run Agent", hostname: "run.local", host_uid: "uid-run", platform: "linux")
    @workflow = Workflow.create!(user: @user, agent: @agent, name: "Run Test")
  end

  test "valid with workflow" do
    run = WorkflowRun.new(workflow: @workflow, trigger_type: :manual)
    assert run.valid?
  end

  test "requires workflow" do
    run = WorkflowRun.new(workflow: nil)
    assert_not run.valid?
  end

  test "status enum" do
    run = WorkflowRun.create!(workflow: @workflow, trigger_type: :manual)
    assert run.pending?
    run.running!
    assert run.running?
    run.completed!
    assert run.completed?
  end

  test "duration returns time difference" do
    run = WorkflowRun.create!(
      workflow: @workflow,
      trigger_type: :manual,
      started_at: 1.hour.ago,
      completed_at: Time.current
    )
    assert run.duration > 3500
  end

  test "duration nil when not completed" do
    run = WorkflowRun.create!(workflow: @workflow, trigger_type: :manual, started_at: 1.hour.ago)
    assert_nil run.duration
  end

  test "recent scope orders by created_at desc" do
    older = WorkflowRun.create!(workflow: @workflow, trigger_type: :manual)
    newer = WorkflowRun.create!(workflow: @workflow, trigger_type: :schedule)
    assert_equal [newer, older], @workflow.workflow_runs.recent.to_a
  end
end
