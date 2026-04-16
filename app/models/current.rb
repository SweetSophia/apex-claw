class Current < ActiveSupport::CurrentAttributes
  attribute :session, :actor, :actor_type, :actor_id, :ip_address, :user_agent
  delegate :user, to: :session, allow_nil: true
end
