class Skill < ApplicationRecord
  belongs_to :user
  has_many :agent_skills, dependent: :destroy
  has_many :agents, through: :agent_skills

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: "already exists in your workspace" }
  validates :body, length: { maximum: 65_535 }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }

  def assigned_to_agent?(agent)
    agents.exists?(agent.id)
  end

  private

  def audit_ignored_change_keys
    super + [ "body" ]
  end
end