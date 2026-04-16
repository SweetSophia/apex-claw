require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = @user.boards.first || @user.boards.create!(name: "Audit Board", icon: "📋", color: "gray")
    @task = Task.create!(user: @user, board: @board, name: "Audited Task")
  end

  test "log! creates an audit log entry" do
    assert_difference "AuditLog.count", 1 do
      AuditLog.log!(
        actor: @user,
        action: "update",
        resource: @task,
        changes: { name: [ "Old", "New" ] },
        ip: "127.0.0.1",
        metadata: { source: "test" }
      )
    end

    audit_log = AuditLog.order(:created_at).last
    assert_equal "User", audit_log.actor_type
    assert_equal @user.id, audit_log.actor_id
    assert_equal "update", audit_log.action
    assert_equal "Task", audit_log.resource_type
    assert_equal @task.id, audit_log.resource_id
    assert_equal [ "Old", "New" ], audit_log.audit_changes["name"]
    assert_equal "127.0.0.1", audit_log.ip_address
    assert_equal "test", audit_log.metadata["source"]
  end

  test "scopes filter audit logs" do
    other_user = users(:two)
    other_board = other_user.boards.first || other_user.boards.create!(name: "Other Board", icon: "📋", color: "gray")
    other_task = Task.create!(user: other_user, board: other_board, name: "Other Task")

    user_log = AuditLog.log!(actor: @user, action: "update", resource: @task)
    resource_log = AuditLog.log!(actor: other_user, action: "destroy", resource: other_task)

    assert_includes AuditLog.by_actor("User", @user.id), user_log
    assert_not_includes AuditLog.by_actor("User", @user.id), resource_log

    assert_includes AuditLog.by_resource("Task", other_task.id), resource_log
    assert_not_includes AuditLog.by_resource("Task", other_task.id), user_log

    assert_includes AuditLog.since(1.minute.ago), user_log
    assert_equal [ resource_log ], AuditLog.recent(1).to_a
  end

  test "readonly protection prevents update and destroy" do
    audit_log = AuditLog.log!(actor: @user, action: "update", resource: @task)

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      audit_log.update!(action: "destroy")
    end

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      audit_log.destroy!
    end
  end
end
