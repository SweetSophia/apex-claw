require "test_helper"

class BoardsTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(status: :up_next)
    sign_in_as(@user)
  end

  test "assign rejects archived agents" do
    agent = Agent.create!(
      user: @user,
      name: "Archived Agent",
      hostname: "archived.local",
      host_uid: "archived-agent-001",
      platform: "linux",
      version: "1.0.0",
      status: :online,
      archived_at: Time.current,
      archived_by: @user
    )

    patch assign_board_task_path(@board, @task), params: { agent_id: agent.id }

    assert_response :redirect
    assert_redirected_to board_path(@board)
    @task.reload
    assert_nil @task.assigned_agent_id
    assert_not @task.assigned_to_agent?
  end
end
