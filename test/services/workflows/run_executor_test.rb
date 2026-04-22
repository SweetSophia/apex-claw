require "test_helper"

class RunExecutorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = @user.boards.first || Board.create!(user: @user, name: "Test Board", icon: "📋", color: "gray")
    @agent = Agent.create!(user: @user, name: "Executor Agent", hostname: "exec.local", host_uid: "uid-exec", platform: "linux", status: :online)
    @workflow = Workflow.create!(user: @user, agent: @agent, name: "Executor Test", execution_mode: :create_task, task_template: { "name" => "Auto task" })
  end

  test "creates a task and assigns to agent" do
    run = @workflow.trigger!(trigger_type: :manual)

    assert_difference "Task.count", 1 do
      Workflows::RunExecutor.new(run).execute!
    end

    run.reload
    assert run.completed?
    created_task = Task.find(run.result["task_id"])
    assert_equal "Auto task", created_task.name
    assert_equal @agent, created_task.assigned_agent
    assert run.result["task_id"].present?
  end

  test "marks failed when agent is not available" do
    @agent.update!(archived_at: Time.current, archived_by: @user)
    run = WorkflowRun.create!(workflow: @workflow, user: @user, trigger_type: :manual, status: :pending)

    Workflows::RunExecutor.new(run).execute!

    run.reload
    assert run.failed?
    assert_match(/not available/, run.error_message)
  end

  test "run_only mode completes without creating task" do
    workflow = Workflow.create!(user: @user, agent: @agent, name: "Run Only", execution_mode: :run_only)
    run = workflow.trigger!(trigger_type: :manual)

    assert_no_difference "Task.count" do
      Workflows::RunExecutor.new(run).execute!
    end

    run.reload
    assert run.completed?
  end

  test "marks failed when no board exists" do
    @user.boards.destroy_all
    run = @workflow.trigger!(trigger_type: :manual)

    Workflows::RunExecutor.new(run).execute!

    run.reload
    assert run.failed?
    assert_match(/No board/, run.error_message)
  end
end
