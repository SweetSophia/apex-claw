module Admin
  class AuditLogsController < ApplicationController
    layout "admin"
    require_admin

    PER_PAGE = 50

    def index
      @filters = filter_params.to_h.compact_blank
      action_filter = @filters["audit_action"]
      @page = [params.fetch(:page, 1).to_i, 1].max

      scope = AuditLog.order(created_at: :desc)
      scope = scope.where(action: action_filter) if action_filter.present?
      scope = scope.where(actor_type: @filters["actor_type"]) if @filters["actor_type"].present?
      scope = scope.where(actor_id: @filters["actor_id"]) if @filters["actor_id"].present?
      scope = scope.where(resource_type: @filters["resource_type"]) if @filters["resource_type"].present?
      scope = scope.where(resource_id: @filters["resource_id"]) if @filters["resource_id"].present?

      # Date range filters
      scope = apply_date_range(scope, @filters)

      @total_count = scope.count
      @audit_logs = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      @has_next_page = @total_count > (@page * PER_PAGE)

      @available_actions = AuditLog.distinct.order(:action).pluck(:action)
      @available_actor_types = AuditLog.distinct.order(:actor_type).where.not(actor_type: [nil, ""]).pluck(:actor_type)
      @available_resource_types = AuditLog.distinct.order(:resource_type).pluck(:resource_type)
    end

    private

    def filter_params
      params.permit(:audit_action, :actor_type, :actor_id, :resource_type, :resource_id, :from, :to)
    end

    def apply_date_range(scope, filters)
      from_date = parse_date(filters["from"])
      to_date = parse_date(filters["to"])

      if from_date
        scope = scope.where("created_at >= ?", from_date.beginning_of_day)
      end

      if to_date
        scope = scope.where("created_at <= ?", to_date.end_of_day)
      end

      scope
    end

    def parse_date(date_string)
      Date.parse(date_string) rescue nil
    end
  end
end
