class CommandPreset < ApplicationRecord
  include Auditable

  audit_events :create, :update, :destroy

  belongs_to :user
  belongs_to :agent, optional: true
  has_many :agent_commands, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: "already exists in your workspace" }
  validates :kind, presence: true, inclusion: { in: AgentCommand::ALLOWED_KINDS }
  validate :agent_belongs_to_user

  scope :active, -> { where(active: true) }
  scope :recent, -> { order(updated_at: :desc) }
  scope :for_agent, ->(agent) { where(agent_id: [nil, agent&.id].compact.uniq) }

  def applicable_to?(target_agent)
    return false unless active?
    return false unless target_agent&.user_id == user_id

    agent_id.nil? || agent_id == target_agent.id
  end

  private

  def agent_belongs_to_user
    return unless agent_id.present?
    return errors.add(:agent_id, "could not be found") unless agent

    errors.add(:agent_id, "must belong to you") unless agent.user_id == user_id
  end
end
