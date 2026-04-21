require "test_helper"

class CommandBarExperienceTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(name: "Command bar task", status: :up_next)
    sign_in_as(@user)
  end

  test "layout seeds command bar with searchable task deep links" do
    get home_path

    assert_response :success
    assert_match "data-command-bar-search-items-value=", response.body
    assert_match board_path(@board, task_id: @task.id), response.body
    assert_match "What should I focus on?", response.body
  end

  test "board layout seeds current board id for inline add fallback" do
    get board_path(@board)

    assert_response :success
    assert_match %(data-command-bar-current-board-id-value="#{@board.id}"), response.body
  end

  test "board show preloads a selected task panel from command bar deep link" do
    get board_path(@board, task_id: @task.id)

    assert_response :success
    assert_match %(data-task-modal-task-id-value="#{@task.id}"), response.body
  end

  test "board show can preload the new task modal from command bar" do
    get board_path(@board, new_task: 1)

    assert_response :success
    assert_match "New Task", response.body
    assert_match 'id="new_task_modal"', response.body
  end
end
