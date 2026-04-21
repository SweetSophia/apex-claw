require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @agent = Agent.create!(
      user: @user,
      name: "Web Agent",
      hostname: "web.local",
      host_uid: "web-agent-001",
      platform: "linux",
      version: "1.0.0",
      status: :online
    )
  end

  test "update_settings drains agent through web controller" do
    patch update_settings_agent_path(@agent), params: { agent: { status: :draining } }

    assert_redirected_to agent_path(@agent)
    assert_equal "draining", @agent.reload.status
  end

  test "archive and restore use web routes" do
    patch archive_agent_path(@agent)
    assert_redirected_to agent_path(@agent)
    assert @agent.reload.archived?

    patch restore_agent_path(@agent)
    assert_redirected_to agent_path(@agent)
    assert_not @agent.reload.archived?
  end

  test "update_config handles invalid json gracefully" do
    patch update_config_agent_path(@agent), params: {
      agent: {
        custom_env: "{bad-json",
        custom_args: "[]"
      }
    }

    assert_response :unprocessable_entity
    assert_match "Invalid JSON format", response.body
  end
end
