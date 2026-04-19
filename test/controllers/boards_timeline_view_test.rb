require "test_helper"

class BoardsTimelineViewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(due_date: Date.current + 2.days, status: :up_next, priority: :medium)
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
end
