require "test_helper"

class Api::V1::AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear

    @user = users(:one)
    @other_user = users(:two)
    @user_token = api_tokens(:one).token

    @agent = Agent.create!(
      user: @user,
      name: "Worker One",
      hostname: "worker-one.local",
      host_uid: "uid-worker-one",
      platform: "linux",
      version: "1.0.0",
      status: :online
    )
    @agent_token, @agent_plaintext_token = AgentToken.issue!(agent: @agent, name: "Primary")

    @other_agent = Agent.create!(
      user: @other_user,
      name: "Worker Two",
      hostname: "worker-two.local",
      host_uid: "uid-worker-two",
      platform: "linux",
      version: "1.0.0",
      status: :online
    )
    AgentToken.issue!(agent: @other_agent, name: "Secondary")
  end

  test "register consumes join token and returns plaintext agent token" do
    join_token, plaintext_join_token = JoinToken.issue!(user: @user, created_by_user: @user)

    assert_difference "Agent.count", 1 do
      assert_difference "AgentToken.count", 1 do
        post "/api/v1/agents/register", params: {
          join_token: plaintext_join_token,
          agent: {
            name: "Batch Worker",
            hostname: "batch-worker.local",
            host_uid: "uid-batch-worker",
            platform: "linux-amd64",
            version: "2.4.0",
            tags: [ "blue", "runner" ],
            metadata: { region: "us-east" }
          }
        }
      end
    end

    assert_response :created
    body = response.parsed_body
    assert body["agent_token"].present?
    assert_equal "Batch Worker", body.dig("agent", "name")
    assert_equal @user.id, body.dig("agent", "user_id")
    assert join_token.reload.used_at.present?
  end

  test "register rejects invalid join token" do
    assert_no_difference "Agent.count" do
      post "/api/v1/agents/register", params: {
        join_token: "invalid-token",
        agent: { name: "Invalid Worker" }
      }
    end

    assert_response :unauthorized
  end

  test "heartbeat requires agent token" do
    post "/api/v1/agents/#{@agent.id}/heartbeat", headers: auth_header(@user_token)
    assert_response :unauthorized
  end

  test "heartbeat allows agent to update itself" do
    post "/api/v1/agents/#{@agent.id}/heartbeat",
         headers: auth_header(@agent_plaintext_token).merge("Content-Type" => "application/json"),
         params: {
           status: "draining",
           version: "2.0.0",
           platform: "linux-arm64",
           metadata: { "load" => 0.5 }
         }.to_json

    assert_response :success
    @agent.reload
    assert_equal "draining", @agent.status
    assert_equal "2.0.0", @agent.version
    assert_equal "linux-arm64", @agent.platform
    assert_equal({ "load" => 0.5 }, @agent.metadata)
    assert @agent.last_heartbeat_at.present?
    assert_equal "none", response.parsed_body.dig("desired_state", "action")
    assert_equal false, response.parsed_body["token_rotation_required"]
    assert_equal 30, response.parsed_body["heartbeat_interval_seconds"]
  end

  test "heartbeat can override interval via apex env" do
    previous = ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"]
    ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"] = "45"

    post "/api/v1/agents/#{@agent.id}/heartbeat", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    assert_equal 45, response.parsed_body["heartbeat_interval_seconds"]
  ensure
    ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"] = previous
  end

  test "heartbeat falls back to legacy interval env" do
    previous = ENV["CLAWDECK_HEARTBEAT_INTERVAL_SECONDS"]
    previous_apex = ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"]
    ENV.delete("APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS")
    ENV["CLAWDECK_HEARTBEAT_INTERVAL_SECONDS"] = "45"

    post "/api/v1/agents/#{@agent.id}/heartbeat", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    assert_equal 45, response.parsed_body["heartbeat_interval_seconds"]
  ensure
    ENV["CLAWDECK_HEARTBEAT_INTERVAL_SECONDS"] = previous
    ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"] = previous_apex
  end

  test "heartbeat clamps interval env to safe bounds" do
    previous = ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"]
    ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"] = "1"

    post "/api/v1/agents/#{@agent.id}/heartbeat", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    assert_equal 5, response.parsed_body["heartbeat_interval_seconds"]
  ensure
    ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"] = previous
  end

  test "heartbeat clamps interval env to upper bound" do
    previous = ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"]
    ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"] = "1000"

    post "/api/v1/agents/#{@agent.id}/heartbeat", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    assert_equal 300, response.parsed_body["heartbeat_interval_seconds"]
  ensure
    ENV["APEX_CLAW_HEARTBEAT_INTERVAL_SECONDS"] = previous
  end

  test "heartbeat flags token rotation when token expires soon" do
    @agent_token.update!(expires_at: 12.hours.from_now)

    post "/api/v1/agents/#{@agent.id}/heartbeat", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    assert_equal true, response.parsed_body["token_rotation_required"]
  end

  test "heartbeat defaults status to online" do
    @agent.update!(status: :offline)

    post "/api/v1/agents/#{@agent.id}/heartbeat", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    assert_equal "online", @agent.reload.status
  end

  test "heartbeat forbids cross-agent updates" do
    post "/api/v1/agents/#{@other_agent.id}/heartbeat", headers: auth_header(@agent_plaintext_token)
    assert_response :forbidden
  end

  test "rotate token revokes old token and returns a new plaintext token" do
    old_digest = @agent_token.token_digest

    assert_difference "AgentToken.count", 1 do
      post "/api/v1/agents/#{@agent.id}/rotate_token", headers: auth_header(@user_token)
    end

    assert_response :created
    body = response.parsed_body
    assert body["agent_token"].present?

    @agent_token.reload
    assert @agent_token.revoked?
    refute_equal old_digest, AgentToken.digest_token(body["agent_token"])

    new_token = @agent.agent_tokens.active.order(created_at: :desc).first
    assert_equal AgentToken.digest_token(body["agent_token"]), new_token.token_digest
    assert_nil AgentToken.authenticate(@agent_plaintext_token)
    assert_equal new_token, AgentToken.authenticate(body["agent_token"])
  end

  test "rotate token is restricted to owner scope" do
    post "/api/v1/agents/#{@other_agent.id}/rotate_token", headers: auth_header(@user_token)
    assert_response :not_found
  end

  test "revoke token revokes active token" do
    post "/api/v1/agents/#{@agent.id}/revoke_token", headers: auth_header(@user_token)

    assert_response :success
    assert_equal 1, response.parsed_body["revoked_tokens"]
    assert @agent_token.reload.revoked?
    assert_nil AgentToken.authenticate(@agent_plaintext_token)
  end

  test "revoke token is restricted to owner scope" do
    post "/api/v1/agents/#{@other_agent.id}/revoke_token", headers: auth_header(@user_token)
    assert_response :not_found
  end

  test "index returns only current user agents" do
    get "/api/v1/agents", headers: auth_header(@user_token)

    assert_response :success
    ids = response.parsed_body.map { |agent| agent["id"] }
    assert_includes ids, @agent.id
    assert_not_includes ids, @other_agent.id
  end

  test "index works for agent token within owner scope" do
    get "/api/v1/agents", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    ids = response.parsed_body.map { |agent| agent["id"] }
    assert_includes ids, @agent.id
    assert_not_includes ids, @other_agent.id
  end

  test "show is restricted to owner scope" do
    get "/api/v1/agents/#{@other_agent.id}", headers: auth_header(@user_token)
    assert_response :not_found
  end

  test "show works with agent token in owner scope" do
    get "/api/v1/agents/#{@agent.id}", headers: auth_header(@agent_plaintext_token)

    assert_response :success
    assert_equal @agent.id, response.parsed_body["id"]
  end

  test "patch updates only safe fields and writes an audit log" do
    assert_difference "AuditLog.count", 1 do
      patch "/api/v1/agents/#{@agent.id}",
            headers: auth_header(@user_token),
            params: {
              agent: {
                name: "Renamed Worker",
                tags: [ "nightly" ],
                status: "disabled",
                metadata: { role: "worker" },
                host_uid: "hijack-attempt"
              }
            }
    end

    assert_response :success
    @agent.reload
    assert_equal "Renamed Worker", @agent.name
    assert_equal [ "nightly" ], @agent.tags
    assert_equal "disabled", @agent.status
    assert_equal({ "role" => "worker" }, @agent.metadata)
    assert_equal "uid-worker-one", @agent.host_uid

    audit_log = AuditLog.order(:created_at).last
    assert_equal "update", audit_log.action
    assert_equal "Agent", audit_log.resource_type
    assert_equal @user.id, audit_log.actor_id
  end

  test "patch is restricted to owner scope" do
    patch "/api/v1/agents/#{@other_agent.id}",
          headers: auth_header(@user_token),
          params: { agent: { name: "Should Not Update" } }

    assert_response :not_found
    assert_not_equal "Should Not Update", @other_agent.reload.name
  end

  test "show returns default rate limit config for owned agent" do
    get "/api/v1/agents/#{@agent.id}/rate_limit", headers: auth_header(@user_token)

    assert_response :success
    assert_equal @agent.id, response.parsed_body["agent_id"]
    assert_equal 60, response.parsed_body["window_seconds"]
    assert_equal 120, response.parsed_body["max_requests"]
  end

  test "update persists custom agent rate limit for owner" do
    put "/api/v1/agents/#{@agent.id}/rate_limit",
        headers: auth_header(@user_token),
        params: { agent_rate_limit: { window_seconds: 30, max_requests: 10 } }

    assert_response :success
    @agent.reload
    assert_equal 30, @agent.agent_rate_limit.window_seconds
    assert_equal 10, @agent.agent_rate_limit.max_requests
  end

  test "rate limit config is restricted to owner scope" do
    get "/api/v1/agents/#{@other_agent.id}/rate_limit", headers: auth_header(@user_token)
    assert_response :not_found
  end

  test "rate limit config rejects agent token access" do
    get "/api/v1/agents/#{@agent.id}/rate_limit", headers: auth_header(@agent_plaintext_token)
    assert_response :forbidden
  end

  test "agent token requests receive rate limit headers and enforce configured limit" do
    @agent.create_agent_rate_limit!(window_seconds: 60, max_requests: 2)

    2.times do |index|
      get "/api/v1/agents", headers: auth_header(@agent_plaintext_token)
      assert_response :success
      assert_equal "2", response.headers["X-RateLimit-Limit"]
      assert_equal (1 - index).to_s, response.headers["X-RateLimit-Remaining"]
      assert response.headers["X-RateLimit-Reset"].present?
    end

    get "/api/v1/agents", headers: auth_header(@agent_plaintext_token)

    assert_response :too_many_requests
    assert_equal "2", response.headers["X-RateLimit-Limit"]
    assert_equal "0", response.headers["X-RateLimit-Remaining"]
    assert response.headers["Retry-After"].present?
    assert_equal "Rate limit exceeded", response.parsed_body["error"]
  end

  # ─── Profile fields ──────────────────────────────────────────────────────

  test "patch updates agent profile fields" do
    patch api_v1_agent_url(@agent),
          headers: auth_header(@user_token),
          params: {
            agent: {
              instructions: "You are a code reviewer.",
              custom_env: { "OPENAI_KEY" => "secret" },
              custom_args: ["--verbose"],
              model: "claude-sonnet-4",
              max_concurrent_tasks: 3
            }
          }

    assert_response :success
    @agent.reload
    assert_equal "You are a code reviewer.", @agent.instructions
    assert_equal({ "OPENAI_KEY" => "secret" }, @agent.custom_env)
    assert_equal(["--verbose"], @agent.custom_args)
    assert_equal "claude-sonnet-4", @agent.model
    assert_equal 3, @agent.max_concurrent_tasks
  end

  test "patch rejects max_concurrent_tasks outside valid range" do
    patch api_v1_agent_url(@agent),
          headers: auth_header(@user_token),
          params: { agent: { max_concurrent_tasks: 999 } }

    assert_response :unprocessable_entity
  end

  test "register accepts profile fields" do
    join_token, plaintext_join_token = JoinToken.issue!(user: @user, created_by_user: @user)

    post "/api/v1/agents/register", params: {
      join_token: plaintext_join_token,
      agent: {
        name: "Profile Agent",
        hostname: "profile.local",
        host_uid: "profile-uid",
        platform: "linux",
        instructions: "You are a researcher.",
        model: "claude-3-opus",
        max_concurrent_tasks: 2
      }
    }

    assert_response :created
    body = response.parsed_body
    assert_equal "You are a researcher.", body.dig("agent", "instructions")
    assert_equal "claude-3-opus", body.dig("agent", "model")
    assert_equal 2, body.dig("agent", "max_concurrent_tasks")
  end

  # ─── Archive / Restore ─────────────────────────────────────────────────

  test "archive marks agent as archived" do
    post "/api/v1/agents/#{@agent.id}/archive", headers: auth_header(@user_token)

    assert_response :success
    assert response.parsed_body["archived_at"].present?
    @agent.reload
    assert @agent.archived?
  end

  test "restore clears archived state" do
    @agent.update!(archived_at: Time.current, archived_by: @user)
    post "/api/v1/agents/#{@agent.id}/restore", headers: auth_header(@user_token)

    assert_response :success
    assert response.parsed_body["archived_at"].nil?
    @agent.reload
    assert_not @agent.archived?
  end

  test "archive is scoped to owner" do
    post "/api/v1/agents/#{@other_agent.id}/archive", headers: auth_header(@user_token)
    assert_response :not_found
  end

  test "restore is scoped to owner" do
    @other_agent.update!(archived_at: Time.current)
    post "/api/v1/agents/#{@other_agent.id}/restore", headers: auth_header(@user_token)
    assert_response :not_found
  end

  test "cannot archive already archived agent" do
    @agent.update!(archived_at: Time.current)
    post "/api/v1/agents/#{@agent.id}/archive", headers: auth_header(@user_token)
    assert_response :unprocessable_entity
  end

  test "cannot restore non-archived agent" do
    post "/api/v1/agents/#{@agent.id}/restore", headers: auth_header(@user_token)
    assert_response :unprocessable_entity
  end

  # ─── Tasks endpoint ────────────────────────────────────────────────────

  test "tasks returns claimed and assigned tasks" do
    board = @user.boards.first || @user.boards.create!(name: "Test Board", icon: "📋", color: "gray")
    Task.create!(user: @user, board: board, name: "Claimed Task", claimed_by_agent: @agent, status: :in_progress)
    Task.create!(user: @user, board: board, name: "Assigned Task", assigned_agent: @agent, status: :up_next)
    Task.create!(user: @user, board: board, name: "Done Task", claimed_by_agent: @agent, status: :done, completed: true, completed_at: Time.current)

    get "/api/v1/agents/#{@agent.id}/tasks", headers: auth_header(@user_token)

    assert_response :success
    body = response.parsed_body
    assert_equal 2, body["claimed"].length
    assert_equal 1, body["assigned"].length
    task_names = body["claimed"].map { |t| t["name"] }
    assert_includes task_names, "Done Task"
    refute_includes task_names, "Assigned Task"
  end

  test "tasks is scoped to owner" do
    get "/api/v1/agents/#{@other_agent.id}/tasks", headers: auth_header(@user_token)
    assert_response :not_found
  end

  # ─── Sibling agent isolation ────────────────────────────────────────────

  test "agent token cannot update sibling agent under same user" do
    sibling = Agent.create!(
      user: @user,
      name: "Sibling Worker",
      hostname: "sibling.local",
      host_uid: "uid-sibling",
      platform: "linux",
      version: "1.0.0"
    )
    _sibling_token, sibling_plaintext = AgentToken.issue!(agent: sibling, name: "Sibling Token")

    patch "/api/v1/agents/#{@agent.id}",
          headers: auth_header(sibling_plaintext),
          params: { agent: { name: "Hijacked Name" } }

    assert_response :forbidden
    assert_not_equal "Hijacked Name", @agent.reload.name
  end

  # ─── Invalid JSON validation ────────────────────────────────────────────

  test "patch returns 422 for invalid JSON in custom_env" do
    patch api_v1_agent_url(@agent),
          headers: auth_header(@user_token).merge("Content-Type" => "application/json"),
          params: { agent: { custom_env: "not-valid-json{" } }.to_json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"].downcase, "invalid json"
  end

  test "patch returns 422 for invalid JSON in custom_args" do
    patch api_v1_agent_url(@agent),
          headers: auth_header(@user_token).merge("Content-Type" => "application/json"),
          params: { agent: { custom_args: "[broken-json" } }.to_json

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"].downcase, "invalid json"
  end

  # ─── Archived agents excluded from tasks/next ──────────────────────────

  test "archived agent receives no tasks from tasks next" do
    board = @user.boards.first || @user.boards.create!(name: "Test Board", icon: "📋", color: "gray")
    Task.create!(user: @user, board: board, name: "Up Next Task", status: :up_next)

    @agent.update!(archived_at: Time.current, archived_by: @user)

    get "/api/v1/tasks/next", headers: auth_header(@agent_plaintext_token)

    assert_response :no_content
  end

  # ─── Archived agents excluded from index ────────────────────────────────

  test "index excludes archived agents by default" do
    archived_agent = Agent.create!(
      user: @user,
      name: "Archived Agent",
      hostname: "archived.local",
      host_uid: "uid-archived",
      platform: "linux",
      version: "1.0.0",
      archived_at: Time.current,
      archived_by: @user
    )

    get "/api/v1/agents", headers: auth_header(@user_token)

    assert_response :success
    ids = response.parsed_body.map { |a| a["id"] }
    assert_includes ids, @agent.id
    assert_not_includes ids, archived_agent.id
  end

  test "index includes archived agents when include_archived is true" do
    archived_agent = Agent.create!(
      user: @user,
      name: "Archived Agent",
      hostname: "archived.local",
      host_uid: "uid-archived",
      platform: "linux",
      version: "1.0.0",
      archived_at: Time.current,
      archived_by: @user
    )

    get "/api/v1/agents?include_archived=true", headers: auth_header(@user_token)

    assert_response :success
    ids = response.parsed_body.map { |a| a["id"] }
    assert_includes ids, @agent.id
    assert_includes ids, archived_agent.id
  end

  private

  def auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
