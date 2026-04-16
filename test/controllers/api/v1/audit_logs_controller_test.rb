require "test_helper"

class Api::V1::AuditLogsControllerTest < ActionController::TestCase
  tests Api::V1::AuditLogsController

  setup do
    @routes = Rails.application.routes
    @admin = users(:admin)
    @user = users(:one)
    @admin_token = api_tokens(:admin).token
    @user_token = api_tokens(:one).token
    @task = tasks(:one)

    AuditLog.log!(actor: @user, action: "create", resource: @task, changes: { name: [ nil, @task.name ] })
  end

  test "admin can list audit logs" do
    assert_equal 1, AuditLog.where(action: "create", resource_type: "Task", resource_id: @task.id).count

    @request.headers["Authorization"] = "Bearer #{@admin_token}"
    get :index, format: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert_equal "create", body.first["action"]
    assert_equal "User", body.first.dig("actor", "type")
    assert_equal @task.id, body.first.dig("resource", "id")
  end

  test "non admin cannot list audit logs" do
    @request.headers["Authorization"] = "Bearer #{@user_token}"
    get :index, format: :json

    assert_response :forbidden
  end

  test "index filters audit logs" do
    @request.headers["Authorization"] = "Bearer #{@admin_token}"
    get :index, params: {
      actor_type: "User",
      actor_id: @user.id,
      resource_type: "Task",
      resource_id: @task.id,
      action: "create"
    }, format: :json

    assert_response :success
    assert_equal 1, JSON.parse(response.body).length
  end
end
