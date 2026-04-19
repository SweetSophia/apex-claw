require "test_helper"

class BroadcastableTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @api_token = api_tokens(:one)
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }
    @board = boards(:one)
  end

  test "SSE endpoint requires authentication" do
    get "/api/v1/events"
    assert_response :unauthorized
  end

  test "task create broadcasts to board Turbo Stream" do
    post api_v1_tasks_url, params: {
      task: { name: "Broadcast test task", board_id: @board.id }
    }, headers: @auth_header
    assert_response :created

    # Verify the task was created (broadcasts happen in after_commit callbacks)
    task = Task.find_by(name: "Broadcast test task")
    assert_not_nil task
  end

  test "task update broadcasts to board Turbo Stream" do
    task = tasks(:one)
    patch api_v1_task_url(task), params: {
      task: { name: "Updated broadcast test" }
    }, headers: @auth_header
    assert_response :success

    task.reload
    assert_equal "Updated broadcast test", task.name
  end

  test "task complete toggles status" do
    task = tasks(:one)
    patch complete_api_v1_task_url(task), headers: @auth_header
    assert_response :success

    task.reload
    assert_equal "done", task.status
  end

  test "agent heartbeat broadcasts status change" do
    agent = Agent.create!(user: @user, name: "Broadcast Test Agent")
    agent_token, plaintext = AgentToken.issue!(agent: agent, name: "Test")
    auth = { "Authorization" => "Bearer #{plaintext}" }

    post heartbeat_api_v1_agent_url(agent), params: { status: "online" }, headers: auth
    assert_response :success

    agent.reload
    assert_equal "online", agent.status
  end

  test "task complete broadcasts structured SSE payload" do
    task = tasks(:one)
    broadcasts = []
    server = ActionCable.server
    singleton = server.singleton_class

    singleton.class_eval do
      alias_method :__broadcastable_test_original_broadcast, :broadcast
    end

    server.define_singleton_method(:broadcast) do |channel, payload|
      broadcasts << [channel, payload]
    end

    patch complete_api_v1_task_url(task), headers: @auth_header
    assert_response :success

    channel, payload = broadcasts.find { |entry| entry.first == "api:events:#{@user.id}" }
    assert_not_nil channel

    body = JSON.parse(payload)
    assert_equal "task.completed", body["type"]
    assert_equal task.id, body.dig("data", "id")
    assert_equal "done", body.dig("data", "status")
    assert body["timestamp"].present?
  ensure
    singleton.class_eval do
      alias_method :broadcast, :__broadcastable_test_original_broadcast
      remove_method :__broadcastable_test_original_broadcast
    end
  end

  test "claim task broadcasts SSE event" do
    task = tasks(:one)
    agent = Agent.create!(user: @user, name: "Claim Agent")
    agent_token, plaintext = AgentToken.issue!(agent: agent, name: "Test")
    auth = { "Authorization" => "Bearer #{plaintext}" }

    patch claim_api_v1_task_url(task), headers: auth
    assert_response :success

    task.reload
    assert_equal agent.id, task.claimed_by_agent_id
  end

  test "heartbeat broadcasts turbo updates for agent card and show dashboard" do
    agent = Agent.create!(user: @user, name: "Realtime Agent")
    _token, plaintext = AgentToken.issue!(agent: agent, name: "Test")
    auth = { "Authorization" => "Bearer #{plaintext}" }
    broadcasts = []
    original = Turbo::StreamsChannel.method(:broadcast_action_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_action_to) do |stream, **kwargs|
      broadcasts << [stream, kwargs]
    end

    post heartbeat_api_v1_agent_url(agent), params: { status: "online", metadata: { task_runner_active: true } }, headers: auth
    assert_response :success

    targets = broadcasts.select { |stream, _| stream == "agents:#{@user.id}" }.map { |_, payload| payload[:target] }
    assert_includes targets, "agent_#{agent.id}"
    assert_includes targets, "agent_show_summary_#{agent.id}"
    assert_includes targets, "agent_show_metadata_#{agent.id}"
    refute_includes targets, "agent_show_tags_#{agent.id}"
    refute_includes targets, "agent_show_commands_#{agent.id}"
    refute_includes targets, "agent_show_tasks_#{agent.id}"
  ensure
    Turbo::StreamsChannel.define_singleton_method(:broadcast_action_to, original)
  end

  test "task completion broadcasts turbo refresh for related agent metrics" do
    agent = Agent.create!(user: @user, name: "Metrics Agent")
    task = Task.create!(user: @user, board: @board, name: "Realtime Task", claimed_by_agent: agent, status: :in_progress)
    broadcasts = []
    original = Turbo::StreamsChannel.method(:broadcast_action_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_action_to) do |stream, **kwargs|
      broadcasts << [stream, kwargs]
    end

    patch complete_api_v1_task_url(task), headers: @auth_header
    assert_response :success

    targets = broadcasts.select { |stream, _| stream == "agents:#{@user.id}" }.map { |_, payload| payload[:target] }
    assert_includes targets, "agent_#{agent.id}"
    assert_includes targets, "agent_show_summary_#{agent.id}"
    assert_includes targets, "agent_show_recent_work_#{agent.id}"
    assert_includes targets, "agent_show_tasks_#{agent.id}"
    refute_includes targets, "agent_show_metadata_#{agent.id}"
    refute_includes targets, "agent_show_commands_#{agent.id}"
  ensure
    Turbo::StreamsChannel.define_singleton_method(:broadcast_action_to, original)
  end

  test "command enqueue broadcasts turbo refresh for agent metrics" do
    agent = Agent.create!(user: @user, name: "Command Metrics Agent")
    broadcasts = []
    original = Turbo::StreamsChannel.method(:broadcast_action_to)

    Turbo::StreamsChannel.define_singleton_method(:broadcast_action_to) do |stream, **kwargs|
      broadcasts << [stream, kwargs]
    end

    post "/api/v1/agents/#{agent.id}/commands", headers: @auth_header, params: { kind: "restart" }
    assert_response :created

    targets = broadcasts.select { |stream, _| stream == "agents:#{@user.id}" }.map { |_, payload| payload[:target] }
    assert_includes targets, "agent_#{agent.id}"
    assert_includes targets, "agent_show_summary_#{agent.id}"
    assert_includes targets, "agent_show_commands_#{agent.id}"
    refute_includes targets, "agent_show_metadata_#{agent.id}"
    refute_includes targets, "agent_show_tasks_#{agent.id}"
  ensure
    Turbo::StreamsChannel.define_singleton_method(:broadcast_action_to, original)
  end
end
