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


  test "owner can enqueue command, agent can poll and complete it, and token rotation invalidates the old token" do
    join_token, plaintext_join_token = JoinToken.issue!(user: @user, created_by_user: @user)

    post "/api/v1/agents/register", params: {
      join_token: plaintext_join_token,
      agent: {
        name: "Command Worker",
        hostname: "command-worker.local",
        host_uid: "command-worker-001",
        platform: "linux-amd64",
        version: "4.0.3"
      }
    }

    assert_response :created
    register_body = response.parsed_body
    agent = Agent.find(register_body.dig("agent", "id"))
    old_agent_token = register_body.fetch("agent_token")

    post "/api/v1/agents/#{agent.id}/commands",
         headers: @user_auth_header,
         params: {
           kind: "drain",
           payload: { reason: "scheduled maintenance" }
         }

    assert_response :created
    enqueue_body = response.parsed_body
    command_id = enqueue_body.fetch("id")
    assert_equal "pending", enqueue_body.fetch("state")
    assert_equal "drain", enqueue_body.fetch("kind")
    assert_equal @user.id, enqueue_body.fetch("requested_by_user_id")

    get "/api/v1/agent_commands/next",
        headers: agent_auth_header(old_agent_token)

    assert_response :success
    next_command_body = response.parsed_body
    assert_equal command_id, next_command_body.fetch("id")
    assert_equal "acknowledged", next_command_body.fetch("state")
    assert_equal "scheduled maintenance", next_command_body.dig("payload", "reason")

    command = AgentCommand.find(command_id)
    assert_equal "acknowledged", command.state
    assert command.acked_at.present?

    patch "/api/v1/agent_commands/#{command.id}/complete",
          headers: agent_auth_header(old_agent_token),
          params: {
            result: {
              success: true,
              message: "Drain completed cleanly"
            }
          }

    assert_response :success
    complete_body = response.parsed_body
    assert_equal "completed", complete_body.fetch("state")
    assert_equal "true", complete_body.dig("result", "success")
    assert_equal "Drain completed cleanly", complete_body.dig("result", "message")

    command.reload
    assert_equal "completed", command.state
    assert command.completed_at.present?

    post "/api/v1/agents/#{agent.id}/rotate_token", headers: @user_auth_header

    assert_response :created
    rotate_body = response.parsed_body
    new_agent_token = rotate_body.fetch("agent_token")
    assert new_agent_token.present?
    refute_equal old_agent_token, new_agent_token

    get "/api/v1/agents", headers: agent_auth_header(old_agent_token)
    assert_response :unauthorized

    get "/api/v1/agents", headers: agent_auth_header(new_agent_token)
    assert_response :success
    ids = response.parsed_body.map { |row| row.fetch("id") }
    assert_includes ids, agent.id

    post heartbeat_api_v1_agent_url(agent),
         headers: agent_auth_header(new_agent_token),
         params: { status: "draining", version: "4.0.3" }

    assert_response :success
    assert_equal "draining", agent.reload.status
  end


  test "assigned agent can hand off a task and target agent can accept it" do
    join_token_one, plaintext_join_token_one = JoinToken.issue!(user: @user, created_by_user: @user)
    join_token_two, plaintext_join_token_two = JoinToken.issue!(user: @user, created_by_user: @user)

    post "/api/v1/agents/register", params: {
      join_token: plaintext_join_token_one,
      agent: {
        name: "Source Worker",
        hostname: "source-worker.local",
        host_uid: "source-worker-001",
        platform: "linux-amd64",
        version: "4.0.3"
      }
    }
    assert_response :created
    source_body = response.parsed_body
    source_agent = Agent.find(source_body.dig("agent", "id"))
    source_token = source_body.fetch("agent_token")

    post "/api/v1/agents/register", params: {
      join_token: plaintext_join_token_two,
      agent: {
        name: "Target Worker",
        hostname: "target-worker.local",
        host_uid: "target-worker-001",
        platform: "linux-amd64",
        version: "4.0.3"
      }
    }
    assert_response :created
    target_body = response.parsed_body
    target_agent = Agent.find(target_body.dig("agent", "id"))
    target_token = target_body.fetch("agent_token")

    post api_v1_tasks_url,
         headers: @user_auth_header,
         params: {
           task: {
             name: "Handoff integration task",
             description: "Verify task handoff acceptance",
             board_id: @board.id,
             status: "in_progress",
             priority: "high"
           }
         }

    assert_response :created
    task_id = response.parsed_body.fetch("id")
    task = Task.find(task_id)
    task.update!(
      assigned_agent: source_agent,
      claimed_by_agent: source_agent,
      agent_claimed_at: Time.current
    )

    post "/api/v1/tasks/#{task.id}/handoff",
         headers: agent_auth_header(source_token),
         params: {
           to_agent_id: target_agent.id,
           context: "Needs a Linux packaging specialist"
         }

    assert_response :created
    create_body = response.parsed_body
    handoff_id = create_body.fetch("id")
    assert_equal task.id, create_body.fetch("task_id")
    assert_equal source_agent.id, create_body.fetch("from_agent_id")
    assert_equal target_agent.id, create_body.fetch("to_agent_id")
    assert_equal "pending", create_body.fetch("status")
    assert_equal "Needs a Linux packaging specialist", create_body.fetch("context")

    get "/api/v1/task_handoffs", headers: agent_auth_header(target_token)
    assert_response :success
    handoff_ids = response.parsed_body.map { |handoff| handoff.fetch("id") }
    assert_includes handoff_ids, handoff_id

    patch "/api/v1/task_handoffs/#{handoff_id}/accept",
          headers: agent_auth_header(target_token)

    assert_response :success
    accept_body = response.parsed_body
    assert_equal "accepted", accept_body.fetch("status")
    assert accept_body.fetch("responded_at").present?

    handoff = TaskHandoff.find(handoff_id)
    assert_equal "accepted", handoff.status
    assert handoff.responded_at.present?

    task.reload
    assert_equal target_agent.id, task.assigned_agent_id
    assert_equal target_agent.id, task.claimed_by_agent_id
    assert task.agent_claimed_at.present?

    activity = task.activities.where(field_name: "handoff", new_value: target_agent.name).order(:created_at).last
    assert_not_nil activity
    assert_equal target_agent.id, activity.actor_agent_id
    assert_equal "api", activity.source
    assert_match(/Handoff accepted:/, activity.note)
  end

  private

  def agent_auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
