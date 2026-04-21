class AgentSkill < ApplicationRecord
  belongs_to :agent
  belongs_to :skill

  validates :agent_id, uniqueness: { scope: :skill_id, message: "already has this skill" }
  validate :skill_belongs_to_same_user

  private

  def skill_belongs_to_same_user
    return if agent_id.blank? || skill_id.blank?
    return if agent.user_id == skill.user_id

    errors.add(:skill, "must belong to the same workspace")
  end
end
