class RoutingRule < ApplicationRecord
  include Auditable

  audit_events :create, :update, :destroy

  belongs_to :user
  belongs_to :agent

  validates :name, presence: true
  validates :conditions, presence: true, allow_blank: true
  validate :conditions_schema
  validate :agent_belongs_to_user

  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :desc, id: :asc) }

  def matches?(task)
    return false unless active?

    conds = conditions
    return true if conds.blank?

    skill_match?(task, conds) &&
      priority_match?(task, conds) &&
      tag_match?(task, conds) &&
      status_match?(task, conds)
  end

  private

  def skill_match?(task, conds)
    required_skills = Array(conds["skills"])
    return true if required_skills.empty?
    return false unless task.respond_to?(:required_skills)

    (required_skills & Array(task.required_skills)).any?
  end

  def priority_match?(task, conds)
    return true if conds["priority"].blank?
    task.priority.to_s == conds["priority"].to_s
  end

  def tag_match?(task, conds)
    required_tags = Array(conds["tags"])
    return true if required_tags.empty?
    return false unless task.respond_to?(:tags)

    (required_tags & Array(task.tags)).any?
  end

  def status_match?(task, conds)
    return true if conds["status"].blank?
    task.status.to_s == conds["status"].to_s
  end

  def conditions_schema
    return if conditions.blank?

    allowed_keys = %w[skills priority tags status]
    invalid_keys = conditions.keys - allowed_keys
    if invalid_keys.any?
      errors.add(:conditions, "contains invalid keys: #{invalid_keys.join(', ')}. Allowed: #{allowed_keys.join(', ')}")
    end

    if conditions["priority"].present? && !Task.priorities.keys.include?(conditions["priority"])
      errors.add(:conditions, "has invalid priority: #{conditions['priority']}. Allowed: #{Task.priorities.keys.join(', ')}")
    end

    if conditions["status"].present? && !Task.statuses.keys.include?(conditions["status"])
      errors.add(:conditions, "has invalid status: #{conditions['status']}. Allowed: #{Task.statuses.keys.join(', ')}")
    end
  end

  def agent_belongs_to_user
    return unless agent_id.present?
    return errors.add(:agent_id, "could not be found") unless agent
    errors.add(:agent_id, "must belong to you") unless agent.user_id == user_id
  end
end
