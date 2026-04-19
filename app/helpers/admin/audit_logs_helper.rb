module Admin
  module AuditLogsHelper
    def audit_log_actor_label(audit_log)
      return "System" if audit_log.actor_type.blank? || audit_log.actor_id.blank?

      "#{audit_log.actor_type} ##{audit_log.actor_id}"
    end

    def audit_log_resource_label(audit_log)
      "#{audit_log.resource_type} ##{audit_log.resource_id}"
    end

    def audit_log_payload_excerpt(payload)
      return "—" if payload.blank?

      json = JSON.pretty_generate(payload)
      truncate(json, length: 180)
    end

    def audit_log_action_badge_class(action)
      case action.to_s
      when /create/
        "bg-emerald-500/15 text-emerald-300"
      when /update|rotate|ack|complete|claim|assign|heartbeat/
        "bg-sky-500/15 text-sky-300"
      when /destroy|revoke|reject|fail/
        "bg-red-500/15 text-red-300"
      else
        "bg-white/[0.08] text-[#bbb]"
      end
    end
  end
end
