require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = @user.boards.first || @user.boards.create!(name: "Test Board", icon: "📋", color: "gray")
  end

  # Validations
  test "requires name" do
    task = Task.new(user: @user, board: @board, name: nil)
    assert_not task.valid?
    assert_includes task.errors[:name], "can't be blank"
  end

  test "valid with required attributes" do
    task = Task.new(user: @user, board: @board, name: "Valid Task")
    assert task.valid?
  end

  test "validates priority inclusion" do
    assert_raises(ArgumentError) do
      Task.new(user: @user, board: @board, name: "Bad Priority", priority: :invalid)
    end
  end

  test "validates status inclusion" do
    assert_raises(ArgumentError) do
      Task.new(user: @user, board: @board, name: "Bad Status", status: :invalid)
    end
  end

  # Associations
  test "belongs to user" do
    task = Task.create!(user: @user, board: @board, name: "Assoc Task")
    assert_equal @user, task.user
  end

  test "belongs to board" do
    task = Task.create!(user: @user, board: @board, name: "Assoc Task")
    assert_equal @board, task.board
  end

  test "has many activities" do
    task = Task.create!(user: @user, board: @board, name: "Activity Task", activity_source: "test")
    assert task.activities.present?
  end

  test "has many subtasks" do
    task = Task.create!(user: @user, board: @board, name: "Subtask Parent")
    task.subtasks.create!(title: "Sub 1")
    task.subtasks.create!(title: "Sub 2")
    assert_equal 2, task.subtasks.count
  end

  # Enum: priority
  test "default priority is none" do
    task = Task.create!(user: @user, board: @board, name: "Priority Task")
    assert_equal "none", task.priority
  end

  test "can set low priority" do
    task = Task.create!(user: @user, board: @board, name: "Low", priority: :low)
    assert_equal "low", task.priority
  end

  test "can set high priority" do
    task = Task.create!(user: @user, board: @board, name: "High", priority: :high)
    assert_equal "high", task.priority
  end

  # Enum: status
  test "default status is inbox" do
    task = Task.create!(user: @user, board: @board, name: "Status Task")
    assert_equal "inbox", task.status
  end

  test "can transition through statuses" do
    task = Task.create!(user: @user, board: @board, name: "Flow Task")
    task.update!(status: :up_next)
    assert_equal "up_next", task.status

    task.update!(status: :in_progress)
    assert_equal "in_progress", task.status

    task.update!(status: :in_review)
    assert_equal "in_review", task.status

    task.update!(status: :done)
    assert_equal "done", task.status
  end

  # Callbacks
  test "setting status to done marks completed as true" do
    task = Task.create!(user: @user, board: @board, name: "Complete Task")
    assert_not task.completed

    task.update!(status: :done)
    assert task.completed
    assert task.completed_at.present?
  end

  test "moving away from done marks completed as false" do
    task = Task.create!(user: @user, board: @board, name: "Toggle Task", status: :done)
    assert task.completed

    task.update!(status: :inbox)
    assert_not task.completed
    assert_nil task.completed_at
  end

  test "position is auto-set on create" do
    task = Task.create!(user: @user, board: @board, name: "Positioned Task")
    assert task.position.present?
    assert task.position > 0
  end

  # Scopes
  test "eligible_for_agent returns up_next unblocked unclaimed tasks" do
    agent = Agent.create!(user: @user, name: "Elig Agent")

    eligible = Task.create!(user: @user, board: @board, name: "Eligible", status: :up_next, blocked: false)
    blocked = Task.create!(user: @user, board: @board, name: "Blocked", status: :up_next, blocked: true)
    in_progress = Task.create!(user: @user, board: @board, name: "In Progress", status: :in_progress, blocked: false)

    results = Task.eligible_for_agent(agent)
    assert_includes results, eligible
    assert_not_includes results, blocked
    assert_not_includes results, in_progress
  end

  test "eligible_for_agent returns only tasks assigned to agent or unassigned" do
    agent1 = Agent.create!(user: @user, name: "Agent 1")
    agent2 = Agent.create!(user: @user, name: "Agent 2")

    assigned_to_1 = Task.create!(user: @user, board: @board, name: "A1 Task", status: :up_next, blocked: false, assigned_agent: agent1)
    assigned_to_2 = Task.create!(user: @user, board: @board, name: "A2 Task", status: :up_next, blocked: false, assigned_agent: agent2)
    unassigned = Task.create!(user: @user, board: @board, name: "Free Task", status: :up_next, blocked: false)

    results = Task.eligible_for_agent(agent1)
    assert_includes results, assigned_to_1
    assert_includes results, unassigned
    assert_not_includes results, assigned_to_2
  end

  test "completed scope returns completed tasks" do
    _incomplete = Task.create!(user: @user, board: @board, name: "Open")
    done = Task.create!(user: @user, board: @board, name: "Done", status: :done)

    results = Task.completed
    assert_includes results, done
    assert_not_includes results, Task.where(name: "Open").first
  end

  test "assigned_to_agent scope returns assigned tasks" do
    assigned = Task.create!(user: @user, board: @board, name: "Assigned", assigned_to_agent: true, assigned_at: Time.current)
    _unassigned = Task.create!(user: @user, board: @board, name: "Unassigned", assigned_to_agent: false)

    results = Task.assigned_to_agent
    assert_includes results, assigned
  end

  # Agent assignment methods
  test "assign_to_agent! sets assigned_to_agent and assigned_at" do
    task = Task.create!(user: @user, board: @board, name: "Assign Task")
    assert_not task.assigned_to_agent

    task.assign_to_agent!
    assert task.assigned_to_agent
    assert task.assigned_at.present?
  end

  test "unassign_from_agent! clears assignment" do
    task = Task.create!(user: @user, board: @board, name: "Unassign Task", assigned_to_agent: true, assigned_at: Time.current)

    task.unassign_from_agent!
    assert_not task.assigned_to_agent
    assert_nil task.assigned_at
  end

  # Output field (issue #43)
  test "output can be stored on task" do
    task = Task.create!(user: @user, board: @board, name: "Output Task", status: :done, output: "Build successful")
    task.reload
    assert_equal "Build successful", task.output
  end

  test "output defaults to nil" do
    task = Task.create!(user: @user, board: @board, name: "No Output")
    assert_nil task.output
  end
end
