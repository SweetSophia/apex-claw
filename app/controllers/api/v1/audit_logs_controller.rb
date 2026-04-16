module Api
  module V1
    class AuditLogsController < BaseController
      before_action :require_admin!

      def index
        filter_action = request.query_parameters["action"] || params[:audit_action]

        audit_logs = AuditLog.all.order(created_at: :desc)
        audit_logs = audit_logs.by_actor(params[:actor_type], params[:actor_id]) if params[:actor_type].present? && params[:actor_id].present?
        audit_logs = audit_logs.by_resource(params[:resource_type], params[:resource_id]) if params[:resource_type].present? && params[:resource_id].present?
        audit_logs = audit_logs.where(action: filter_action) if filter_action.present?

        page = params.fetch(:page, 1).to_i
        per_page = [ params.fetch(:per_page, 25).to_i, 100 ].min
        per_page = 25 if per_page <= 0
        page = 1 if page <= 0

        audit_logs = audit_logs.offset((page - 1) * per_page).limit(per_page)

        render json: audit_logs.map { |audit_log| audit_log_json(audit_log) }
      end

      private

      def require_admin!
        return if current_user&.admin?

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def audit_log_json(audit_log)
        {
          id: audit_log.id,
          actor: {
            type: audit_log.actor_type,
            id: audit_log.actor_id
          },
          action: audit_log.action,
          resource: {
            type: audit_log.resource_type,
            id: audit_log.resource_id
          },
          changes: audit_log.audit_changes,
          ip: audit_log.ip_address,
          created_at: audit_log.created_at.iso8601
        }
      end
    end
  end
end
