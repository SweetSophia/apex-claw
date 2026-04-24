require "test_helper"

class Admin::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @user = users(:one)
    @task = tasks(:one)

    @task_log = AuditLog.log!(
      actor: @user,
      action: "task.claimed",
      resource: @task,
      changes: { "claimed_by_agent_id" => [nil, 123] },
      metadata: { source: "api" }
    )
    @agent_log = AuditLog.log!(
      actor: @admin,
      action: "agent.heartbeat",
      resource: @task,
      changes: { "status" => ["offline", "online"] },
      metadata: { source: "agent", platform: "linux" }
    )
  end

  test "admin can view audit logs index" do
    sign_in_as(@admin)

    get admin_audit_logs_path

    assert_response :success
    assert_match "Audit Logs", response.body
    assert_match @task_log.action, response.body
    assert_match @agent_log.action, response.body
    assert_match "Task ##{@task.id}", response.body
  end

  test "non admin gets not found" do
    sign_in_as(@user)

    get admin_audit_logs_path

    assert_response :not_found
  end

  test "audit logs index filters by action and actor" do
    sign_in_as(@admin)

    get admin_audit_logs_path, params: { audit_action: "task.claimed", actor_type: "User", actor_id: @user.id }

    assert_response :success
    # New UI uses article elements with action badges (span.inline-flex) instead of tbody tr
    assert_select "article", count: 1
    assert_select "article span.inline-flex", text: "task.claimed", count: 1
    assert_select "article span.inline-flex", text: "agent.heartbeat", count: 0
  end

  test "admin dashboard links to audit logs" do
    sign_in_as(@admin)

    get admin_root_path

    assert_response :success
    assert_match "Audit Log Entries", response.body
    assert_match admin_audit_logs_path, response.body
  end
end
