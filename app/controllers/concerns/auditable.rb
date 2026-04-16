module Auditable
  extend ActiveSupport::Concern

  included do
    class_attribute :audit_actions, instance_accessor: false, default: [ :create, :update, :destroy ]

    after_create :audit_create_if_enabled
    after_update :audit_update_if_enabled
    after_destroy :audit_destroy_if_enabled
  end

  class_methods do
    def audit_events(*events)
      self.audit_actions = events.flatten.map(&:to_sym)
    end
  end

  private

  def audit_create_if_enabled
    return unless audit_enabled?(:create)

    AuditLog.log!(
      actor: Current.actor,
      action: "create",
      resource: self,
      changes: audited_create_changes,
      metadata: audit_metadata
    )
  end

  def audit_update_if_enabled
    return unless audit_enabled?(:update)

    changes = audited_update_changes
    return if changes.empty?

    AuditLog.log!(
      actor: Current.actor,
      action: audit_update_action_name,
      resource: self,
      changes: changes,
      metadata: audit_metadata
    )
  end

  def audit_destroy_if_enabled
    return unless audit_enabled?(:destroy)

    AuditLog.log!(
      actor: Current.actor,
      action: "destroy",
      resource: self,
      changes: audited_destroy_changes,
      metadata: audit_metadata
    )
  end

  def audit_enabled?(event)
    self.class.audit_actions.include?(event)
  end

  def audited_create_changes
    previous_changes.except(*audit_ignored_change_keys)
  end

  def audited_update_changes
    saved_changes.except(*audit_ignored_change_keys)
  end

  def audited_destroy_changes
    attributes.except(*audit_ignored_attribute_keys)
  end

  def audit_ignored_change_keys
    [ "created_at", "updated_at" ]
  end

  def audit_ignored_attribute_keys
    [ "updated_at" ]
  end

  def audit_update_action_name
    if respond_to?(:saved_change_to_status?) && saved_change_to_status? && respond_to?(:status)
      status == "done" ? "complete" : "update"
    else
      "update"
    end
  end

  def audit_metadata
    {}
  end
end
