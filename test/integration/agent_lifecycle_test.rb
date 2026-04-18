require "test_helper"

class AgentLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear

    @user = users(:one)
    @board = boards(:one)
    @user_auth_header = { "Authorization" => "Bearer #{api_tokens(:one).token}" }
  end

  test "agent can register, heartbeat, claim next task, and complete it with output" do
    join_token, plaintext_join_token = JoinToken.issue!(user: @user, created_by_user: @user)

    post "/api/v1/agents/register", params: {
      join_token: plaintext_join_token,
      agent: {
        name: "Lifecycle Worker",
        hostname: "lifecycle-worker.local",
        host_uid: "lifecycle-worker-001",
        platform: "linux-amd64",
        version: "4.0.3",
        metadata: { queue: "default" }
      }
    }

    assert_response :created
    register_body = response.parsed_body
    agent_id = register_body.dig("agent", "id")
    agent_token = register_body.fetch("agent_token")

    assert agent_token.present?
    assert_equal @user.id, register_body.dig("agent", "user_id")
    assert join_token.reload.used_at.present?

    agent = Agent.find(agent_id)

    post heartbeat_api_v1_agent_url(agent),
         headers: agent_auth_header(agent_token).merge("X-Agent-Name" => "Lifecycle Worker", "X-Agent-Emoji" => "🤖"),
         params: {
           status: "online",
           version: "4.0.3",
           platform: "linux-amd64",
           metadata: {
             uptime_seconds: 123,
             task_runner_active: true
           }
         }

    assert_response :success
    heartbeat_body = response.parsed_body
    assert_equal "none", heartbeat_body.dig("desired_state", "action")
    assert_equal false, heartbeat_body.fetch("token_rotation_required")

    agent.reload
    assert_equal "online", agent.status
    assert_equal "4.0.3", agent.version
    assert_equal "linux-amd64", agent.platform
    assert_equal "123", agent.metadata["uptime_seconds"]
    assert_equal "true", agent.metadata["task_runner_active"]
    assert agent.last_heartbeat_at.present?

    post api_v1_tasks_url,
         headers: @user_auth_header,
         params: {
           task: {
             name: "End-to-end lifecycle task",
             description: "Verify agent lifecycle flow",
             board_id: @board.id,
             status: "up_next",
             priority: "high"
           }
         }

    assert_response :created
    task_id = response.parsed_body.fetch("id")

    get next_api_v1_tasks_url,
        headers: agent_auth_header(agent_token).merge("X-Agent-Name" => "Lifecycle Worker", "X-Agent-Emoji" => "🤖")

    assert_response :success
    next_task_body = response.parsed_body
    assert_equal task_id, next_task_body.fetch("id")
    assert_equal "in_progress", next_task_body.fetch("status")

    task = Task.find(task_id)
    assert_equal agent.id, task.claimed_by_agent_id
    assert task.agent_claimed_at.present?

    patch api_v1_task_url(task),
          headers: agent_auth_header(agent_token).merge("X-Agent-Name" => "Lifecycle Worker", "X-Agent-Emoji" => "🤖"),
          params: {
            task: {
              status: "done",
              output: "Completed successfully via integration test"
            },
            activity_note: "Lifecycle integration completion"
          }

    assert_response :success
    completion_body = response.parsed_body
    assert_equal "done", completion_body.fetch("status")
    assert_equal "Completed successfully via integration test", completion_body.fetch("output")

    task.reload
    assert_equal "done", task.status
    assert_equal "Completed successfully via integration test", task.output
    assert task.completed_at.present?

    status_activity = task.activities.where(action: "moved", new_value: "done").order(:created_at).last
    assert_not_nil status_activity
    assert_equal agent.id, status_activity.actor_agent_id
    assert_equal "api", status_activity.source
    assert_equal "Lifecycle Worker", status_activity.actor_name
    assert_equal "🤖", status_activity.actor_emoji
    assert_equal "Lifecycle integration completion", status_activity.note
  end

  private

  def agent_auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
