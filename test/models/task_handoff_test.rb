require "test_helper"

class TaskHandoffTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @task = tasks(:one)
    @from_agent = Agent.create!(user: @user, name: "From Agent")
    @to_agent = Agent.create!(user: @user, name: "To Agent")
  end

  test "valid handoff" do
    handoff = TaskHandoff.new(
      task: @task,
      from_agent: @from_agent,
      to_agent: @to_agent,
      context: "Please take this task"
    )
    assert handoff.valid?
  end

  test "requires context" do
    handoff = TaskHandoff.new(
      task: @task,
      from_agent: @from_agent,
      to_agent: @to_agent,
      context: ""
    )
    assert_not handoff.valid?
    assert_includes handoff.errors[:context], "can't be blank"
  end

  test "from and to agent must differ" do
    handoff = TaskHandoff.new(
      task: @task,
      from_agent: @from_agent,
      to_agent: @from_agent,
      context: "Self handoff"
    )
    assert_not handoff.valid?
  end


  test "disallows multiple pending handoffs for the same task" do
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    other_agent = Agent.create!(user: @user, name: "Other Target")

    handoff = TaskHandoff.new(task: @task, from_agent: @from_agent, to_agent: other_agent, context: "B")

    assert_not handoff.valid?
    assert_includes handoff.errors[:task_id], "already has a pending handoff"
  end

  test "status defaults to pending" do
    handoff = TaskHandoff.create!(
      task: @task,
      from_agent: @from_agent,
      to_agent: @to_agent,
      context: "Test"
    )
    assert handoff.pending?
  end

  test "pending scope" do
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "B", status: :accepted)

    assert_equal 1, TaskHandoff.pending.count
  end

  test "for_agent scope" do
    other_agent = Agent.create!(user: @user, name: "Other")
    other_task = Task.create!(user: @user, board: @task.board, name: "Another Task")
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    TaskHandoff.create!(task: other_task, from_agent: other_agent, to_agent: @from_agent, context: "B")

    results = TaskHandoff.for_agent(@from_agent.id)
    assert_equal 2, results.count
  end

  test "for_task scope" do
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")

    assert_equal 1, TaskHandoff.for_task(@task.id).count
  end

  test "accept! transitions status" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    assert handoff.accept!
    assert handoff.accepted?
    assert handoff.responded_at.present?
  end

  test "reject! transitions status" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    assert handoff.reject!
    assert handoff.rejected?
  end

  test "expire! transitions status" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    assert handoff.expire!
    assert handoff.expired?
  end

  test "cannot accept non-pending handoff" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A", status: :accepted)
    assert_not handoff.accept!
  end

  test "expire_stale! expires old pending handoffs" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "Old")
    handoff.update_column(:created_at, 10.minutes.ago)

    TaskHandoff.expire_stale!
    assert handoff.reload.expired?
  end
end
