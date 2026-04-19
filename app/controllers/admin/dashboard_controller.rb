module Admin
  class DashboardController < ApplicationController
    layout "admin"
    require_admin

    def index
      @total_users = User.count
      @total_tasks = Task.count
      @recent_signups = User.where("created_at >= ?", 7.days.ago).count
      @total_audit_logs = AuditLog.count
      @recent_audit_logs = AuditLog.order(created_at: :desc).limit(5)
    end
  end
end
