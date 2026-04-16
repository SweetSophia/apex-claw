class AuditLog < ApplicationRecord
  self.record_timestamps = false

  scope :by_actor, ->(type, id) { where(actor_type: type, actor_id: id) }
  scope :by_resource, ->(type, id) { where(resource_type: type, resource_id: id) }
  scope :recent, ->(count = 20) { order(created_at: :desc).limit(count) }
  scope :since, ->(date) { where(arel_table[:created_at].gteq(date)) }

  validates :action, presence: true
  validates :resource_type, presence: true
  validates :resource_id, presence: true

  before_destroy :raise_readonly_record

  def readonly?
    persisted?
  end

  def self.log!(actor:, action:, resource:, changes: nil, ip: nil, metadata: {})
    actor_type, actor_id = extract_actor(actor)

    audit_log = new(
      actor_type: actor_type,
      actor_id: actor_id,
      action: action,
      resource_type: resource.class.base_class.name,
      resource_id: resource.id,
      ip_address: ip || Current.ip_address,
      user_agent: Current.user_agent,
      metadata: normalize_payload(metadata),
      created_at: Time.current
    )
    audit_log.audited_changes = normalize_payload(changes)
    audit_log.save!
    audit_log
  end

  def audit_changes
    audited_changes
  end

  private

  def raise_readonly_record
    raise ActiveRecord::ReadOnlyRecord, "Audit logs are immutable"
  end

  def self.extract_actor(actor)
    actor ||= Current.actor

    if actor.present?
      [ actor.class.base_class.name, actor.id ]
    else
      [ Current.actor_type, Current.actor_id ]
    end
  end

  def self.normalize_payload(payload)
    case payload
    when nil
      {}
    when Hash
      payload.deep_stringify_keys
    else
      payload.as_json
    end
  end

  private_class_method :extract_actor, :normalize_payload
end
