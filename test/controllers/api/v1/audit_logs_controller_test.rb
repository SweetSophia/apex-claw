require "test_helper"

class Api::V1::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
    @admin_token = api_tokens(:admin).token
    @user_token = api_tokens(:one).token
    @task = tasks(:one)

    AuditLog.log!(actor: @user, action: "create", resource: @task, changes: { name: [ nil, @task.name ] })
  end

  test "admin can list audit logs" do
    get "/api/v1/audit_logs", headers: auth_header(@admin_token)

    assert_response :success
    body = response.parsed_body
    assert_kind_of Array, body
    assert_equal "create", body.first["action"]
    assert_equal "User", body.first.dig("actor", "type")
    assert_equal @task.id, body.first.dig("resource", "id")
  end

  test "non admin cannot list audit logs" do
    get "/api/v1/audit_logs", headers: auth_header(@user_token)

    assert_response :forbidden
  end

  test "index filters audit logs" do
    get "/api/v1/audit_logs",
        headers: auth_header(@admin_token),
        params: { actor_type: "User", actor_id: @user.id, resource_type: "Task", resource_id: @task.id, action: "create" }

    assert_response :success
    assert_equal 1, response.parsed_body.length
  end

  private

  def auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
