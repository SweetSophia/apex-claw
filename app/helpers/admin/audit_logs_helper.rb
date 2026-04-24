module Admin
  module AuditLogsHelper
    ROUTABLE_ACTOR_TYPES = %w[Agent Skill Workflow HandoffTemplate RoutingRule CommandPreset Board User].freeze
    ROUTABLE_RESOURCE_TYPES = %w[Agent Skill Workflow HandoffTemplate RoutingRule CommandPreset Board Task User].freeze

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

    # Returns a concise one-line summary of audit_changes for list view
    def audit_log_change_summary(audit_log)
      changes = audit_log.audit_changes || audit_log.audited_changes
      return "—" if changes.blank?

      case changes
      when Hash
        keys = changes.keys
        count = keys.size
        if count == 1
          "Changed #{keys.first}"
        elsif count <= 3
          "Changed #{keys.join(", ")}"
        else
          "Changed #{count} fields"
        end
      when Array
        count = changes.size
        count == 1 ? "1 change" : "#{count} changes"
      else
        "View details"
      end
    end

    # Renders up to `limit` metadata chips as small inline badges
    def audit_log_metadata_chips(audit_log, limit: 2)
      metadata = audit_log.metadata
      return "".html_safe if metadata.blank?

      chips = metadata.take(limit).map do |key, value|
        truncated = audit_log_value_preview(value)
        content_tag(:span, "#{key}: #{truncated}",
          class: "inline-flex items-center rounded bg-bg-elevated border border-white/[0.06] px-1.5 py-0.5 text-[10px] text-content-secondary font-mono"
        )
      end

      safe_join(chips)
    end

    # Returns active filter chips with remove links
    def audit_log_filter_chips(filters)
      chips = []

      labels = {
        "audit_action" => "Action",
        "actor_type" => "Actor type",
        "actor_id" => "Actor ID",
        "resource_type" => "Resource type",
        "resource_id" => "Resource ID",
        "from" => "From",
        "to" => "To"
      }

      filters.each do |key, value|
        next if value.blank?
        next unless labels.key?(key)

        label = labels[key]
        display = key == "from" || key == "to" ? value : value
        remove_params = filters.except(key)
        url = admin_audit_logs_path(remove_params)

        chips << content_tag(:span,
          "#{label}: #{display} ".html_safe +
          link_to("×", url, class: "ml-1 text-content-muted hover:text-content focus-visible:ring-1 rounded"),
          class: "inline-flex items-center rounded bg-bg-elevated border border-white/[0.08] px-2 py-1 text-xs text-content"
        )
      end

      safe_join(chips)
    end

    # Safe link for actor — only for known routable types
    def audit_log_linked_actor(audit_log)
      return content_tag(:span, "System", class: "text-content-muted") if audit_log.actor_type.blank? || audit_log.actor_id.blank?

      type = audit_log.actor_type
      id = audit_log.actor_id

      unless ROUTABLE_ACTOR_TYPES.include?(type)
        return content_tag(:span, audit_log_actor_label(audit_log), class: "text-content")
      end

      path = actor_path_for_type(type, id)
      if path
        link_to(audit_log_actor_label(audit_log), path,
          class: "text-accent hover:text-accent-hover focus-visible:ring-1 rounded")
      else
        content_tag(:span, audit_log_actor_label(audit_log), class: "text-content")
      end
    rescue StandardError
      content_tag(:span, audit_log_actor_label(audit_log), class: "text-content-muted")
    end

    # Safe link for resource — only for known routable types, Task gets board_task_path
    def audit_log_linked_resource(audit_log)
      return content_tag(:span, "—", class: "text-content-muted") if audit_log.resource_type.blank? || audit_log.resource_id.blank?

      type = audit_log.resource_type
      id = audit_log.resource_id

      if type == "Task"
        return link_task_resource(id)
      end

      unless ROUTABLE_RESOURCE_TYPES.include?(type)
        return content_tag(:span, audit_log_resource_label(audit_log), class: "text-content")
      end

      path = resource_path_for_type(type, id)
      if path
        link_to(audit_log_resource_label(audit_log), path,
          class: "text-accent hover:text-accent-hover focus-visible:ring-1 rounded")
      else
        content_tag(:span, audit_log_resource_label(audit_log), class: "text-content")
      end
    rescue StandardError
      content_tag(:span, audit_log_resource_label(audit_log), class: "text-content-muted")
    end

    # Quick filter link chips for investigation rail
    def audit_log_quick_views
      [
        { label: "All activity", params: {} },
        { label: "Today", params: { from: Date.current.iso8601 } },
        { label: "Last 7 days", params: { from: 7.days.ago.to_date.iso8601 } },
        { label: "Task changes", params: { resource_type: "Task" } },
        { label: "Agent activity", params: { actor_type: "Agent" } },
        { label: "Destructive", params: { audit_action: "destroy" } }
      ]
    end

    # Format a single value for display in structured diffs
    def audit_log_value_preview(value)
      case value
      when Hash, Array
        str = value.is_a?(Hash) ? JSON.generate(value) : JSON.generate(value)
        truncate(str, length: 40)
      when true
        "true"
      when false
        "false"
      when nil
        "nil"
      else
        str = value.to_s
        str.length > 40 ? "#{str[0..37]}..." : str
      end
    end

    private

    def actor_path_for_type(type, id)
      case type
      when "Agent" then agent_path(id)
      when "Skill" then skill_path(id)
      when "Workflow" then workflow_path(id)
      when "HandoffTemplate" then handoff_template_path(id)
      when "RoutingRule" then routing_rule_path(id)
      when "CommandPreset" then command_preset_path(id)
      when "Board" then board_path(id)
      when "User" then nil # User is not admin-routable in this context
      else nil
      end
    end

    def resource_path_for_type(type, id)
      case type
      when "Agent" then agent_path(id)
      when "Skill" then skill_path(id)
      when "Workflow" then workflow_path(id)
      when "HandoffTemplate" then handoff_template_path(id)
      when "RoutingRule" then routing_rule_path(id)
      when "CommandPreset" then command_preset_path(id)
      when "Board" then board_path(id)
      when "User" then nil
      else nil
      end
    end

    def link_task_resource(id)
      task = Task.find_by(id: id)
      return content_tag(:span, "Task ##{id}", class: "text-content-muted") unless task

      link_to("Task ##{id}", board_task_path(task.board, task),
        class: "text-accent hover:text-accent-hover focus-visible:ring-1 rounded")
    rescue StandardError
      content_tag(:span, "Task ##{id}", class: "text-content-muted")
    end
  end
end
