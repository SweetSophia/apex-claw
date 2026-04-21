require "test_helper"

class Api::V1::CommandPresetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @user = users(:one)
    @other_user = users(:two)
    @user_token = api_tokens(:one).token

    @agent = Agent.create!(
      user: @user,
      name: "Preset Agent",
      hostname: "preset-agent.local",
      host_uid: "uid-preset-agent",
      platform: "linux",
      version: "1.0.0"
    )
    _agent_token, @agent_plaintext_token = AgentToken.issue!(agent: @agent, name: "Preset Agent Token")

    @other_agent = Agent.create!(
      user: @other_user,
      name: "Other Preset Agent",
      hostname: "other-preset-agent.local",
      host_uid: "uid-other-preset-agent",
      platform: "linux",
      version: "1.0.0"
    )

    @preset = CommandPreset.create!(
      user: @user,
      agent: @agent,
      name: "Restart Preset",
      kind: "restart",
      description: "Restart the agent",
      payload: { reason: "scheduled" }
    )
    @other_preset = CommandPreset.create!(
      user: @other_user,
      agent: @other_agent,
      name: "Other User Preset",
      kind: "drain"
    )
  end

  test "index returns presets for current user" do
    get "/api/v1/command_presets", headers: auth_header(@user_token)

    assert_response :success
    assert_equal [ @preset.id ], response.parsed_body["command_presets"].map { |preset| preset["id"] }
  end

  test "create works with user token" do
    assert_difference "CommandPreset.count", 1 do
      post "/api/v1/command_presets",
           headers: auth_header(@user_token),
           params: {
             command_preset: {
               name: "Health Check",
               kind: "health_check",
               description: "Run a health check",
               agent_id: @agent.id,
               payload: { source: "api" },
               active: true
             }
           }
    end

    assert_response :created
    assert_equal "Health Check", response.parsed_body["command_preset"]["name"]
  end

  test "create is forbidden for agent token" do
    assert_no_difference "CommandPreset.count" do
      post "/api/v1/command_presets",
           headers: auth_header(@agent_plaintext_token),
           params: { command_preset: { name: "Blocked", kind: "restart" } }
    end

    assert_response :forbidden
  end

  test "show is scoped to current user" do
    get "/api/v1/command_presets/#{@preset.id}", headers: auth_header(@user_token)

    assert_response :success
    assert_equal "Restart Preset", response.parsed_body["command_preset"]["name"]
  end

  test "update is scoped to current user" do
    patch "/api/v1/command_presets/#{@preset.id}",
          headers: auth_header(@user_token),
          params: { command_preset: { name: "Updated Preset", active: false } }

    assert_response :success
    assert_equal "Updated Preset", @preset.reload.name
    assert_equal false, @preset.active
  end

  test "destroy is scoped to current user" do
    assert_difference "CommandPreset.count", -1 do
      delete "/api/v1/command_presets/#{@preset.id}", headers: auth_header(@user_token)
    end

    assert_response :no_content
  end

  test "cannot show another user's preset" do
    get "/api/v1/command_presets/#{@other_preset.id}", headers: auth_header(@user_token)

    assert_response :not_found
  end

  test "cannot update another user's preset" do
    patch "/api/v1/command_presets/#{@other_preset.id}",
          headers: auth_header(@user_token),
          params: { command_preset: { name: "Hacked" } }

    assert_response :not_found
    assert_equal "Other User Preset", @other_preset.reload.name
  end

  test "cannot destroy another user's preset" do
    assert_no_difference "CommandPreset.count" do
      delete "/api/v1/command_presets/#{@other_preset.id}", headers: auth_header(@user_token)
    end

    assert_response :not_found
  end

  private

  def auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
