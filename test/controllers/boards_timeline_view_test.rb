require "test_helper"

class BoardsTimelineViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(due_date: Date.current + 2.days, status: :up_next, priority: :medium, tags: ["ops"])
    sign_in_as(@user)
  end

  test "board show renders timeline view when requested" do
    get board_path(@board, view: "timeline")

    assert_response :success
    assert_match "Timeline", response.body
    assert_match @task.name, response.body
    assert_match @task.due_date.strftime("%b %-d"), response.body
  end

  test "board show falls back to board view for unknown view mode" do
    get board_path(@board, view: "unknown")

    assert_response :success
    assert_match "Board", response.body
    assert_match "Add a card", response.body
  end

  test "timeline respects active tag filters and keeps timeline view on clear filter" do
    other_task = @board.tasks.create!(
      name: "Unrelated task",
      user: @user,
      status: :inbox,
      priority: :none,
      completed: false,
      due_date: Date.current + 4.days,
      tags: ["other"]
    )

    get board_path(@board, view: "timeline", tag: "ops")

    assert_response :success
    assert_match @task.name, response.body
    assert_no_match other_task.name, response.body
    assert_match board_path(@board, view: "timeline"), response.body
  end

  test "timeline expands to include the furthest due date" do
    far_task = @board.tasks.create!(
      name: "Far future task",
      user: @user,
      status: :in_progress,
      priority: :high,
      completed: false,
      due_date: Date.current + 25.days
    )

    get board_path(@board, view: "timeline")

    assert_response :success
    assert_match far_task.name, response.body
    assert_match far_task.due_date.strftime("%b %-d"), response.body
    assert_match far_task.due_date.strftime("%-d"), response.body
  end

  test "timeline shows empty state when no tasks have due dates" do
    @board.tasks.update_all(due_date: nil)

    get board_path(@board, view: "timeline")

    assert_response :success
    assert_match "No scheduled tasks yet", response.body
  end


  test "timeline caps the visible date window and shows a truncation note" do
    far_task = @board.tasks.create!(
      name: "Extremely far future task",
      user: @user,
      status: :in_progress,
      priority: :high,
      completed: false,
      due_date: Date.current + 180.days
    )

    get board_path(@board, view: "timeline")

    assert_response :success
    assert_match far_task.name, response.body
    assert_match "Showing the next 90 days", response.body
    assert_match "grid-template-columns: repeat(90, minmax(40px, 1fr));", response.body
  end

  test "view toggle exposes tab semantics" do
    get board_path(@board, view: "timeline")

    assert_response :success
    assert_match 'role="tablist"', response.body
    assert_match 'aria-label="Board view modes"', response.body
    assert_match 'role="tab"', response.body
    assert_match 'aria-selected="true"', response.body
  end
end
