class AgentCommand < ApplicationRecord
  include Auditable

  audit_events :create

  belongs_to :agent
  belongs_to :requested_by_user, class_name: "User", optional: true

  enum :state, {
    pending: 0,
    acknowledged: 1,
    completed: 2,
    failed: 3
  }, default: :pending

  validates :kind, presence: true

  after_commit :broadcast_agent_dashboard

  scope :for_agent, ->(agent) { where(agent: agent) }
  scope :pending_for, ->(agent) { for_agent(agent).pending }
  private

  def broadcast_agent_dashboard
    Agent.broadcast_dashboard_update(agent, sections: [:card, :summary, :commands])
  end
end
