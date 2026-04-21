class AgentCommand < ApplicationRecord
  include Auditable

  ALLOWED_KINDS = %w[drain resume restart health_check config_reload].freeze

  audit_events :create, :update

  belongs_to :agent
  belongs_to :command_preset, optional: true
  belongs_to :requested_by_user, class_name: "User", optional: true

  enum :state, {
    pending: 0,
    acknowledged: 1,
    completed: 2,
    failed: 3
  }, default: :pending

  validates :kind, presence: true, inclusion: { in: ALLOWED_KINDS }

  after_commit :broadcast_agent_dashboard

  scope :for_agent, ->(agent) { where(agent: agent) }
  scope :pending_for, ->(agent) { for_agent(agent).pending }
  scope :recent, -> { order(created_at: :desc) }
  scope :failed_recent, ->(window = 24.hours) { failed.where(created_at: window.ago..) }
  scope :long_running, ->(threshold = 10.minutes) { acknowledged.where(acked_at: ..threshold.ago) }

  private

  def broadcast_agent_dashboard
    Agent.broadcast_dashboard_update(agent, sections: [:card, :summary, :commands])
  end
end
