require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(name: "Helper task", status: :up_next)
  end

  test "command bar new task action carries board id and deep link for current board" do
    items = helper_context.command_bar_search_items(@user, current_board: @board, tasks_scope: @board.tasks)
    new_task = items.find { |item| item[:actionType] == "new_task" }

    assert_not_nil new_task
    assert_equal @board.id, new_task[:boardId]
    assert_equal helper_context.board_path(@board, new_task: 1), new_task[:href]
  end

  test "command bar falls back to the user's first board when no current board is present" do
    items = helper_context.command_bar_search_items(@user)
    new_task = items.find { |item| item[:actionType] == "new_task" }

    assert_not_nil new_task
    assert_equal @board.id, new_task[:boardId]
    assert_equal helper_context.board_path(@board, new_task: 1), new_task[:href]
  end

  private

  def helper_context
    @helper_context ||= Class.new do
      include ApplicationHelper
      include Rails.application.routes.url_helpers

      def default_url_options
        {}
      end
    end.new
  end
end
