class HandoffTemplate < ApplicationRecord
  include Auditable

  audit_events :create, :update, :destroy

  belongs_to :user
  belongs_to :agent, optional: true

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: "already exists in your workspace" }
  validates :context_template, presence: true

  scope :recent, -> { order(updated_at: :desc) }
  scope :auto_suggest, -> { where(auto_suggest: true) }

  def render_context(task: nil, from_agent: nil)
    template = context_template.dup
    return template unless task

    template.gsub("{{task_name}}", task.name.to_s)
            .gsub("{{task_description}}", task.description.to_s)
            .gsub("{{task_priority}}", task.priority.to_s)
            .gsub("{{task_status}}", task.status.to_s)
            .gsub("{{task_tags}}", (task.tags || []).join(", "))
            .gsub("{{from_agent}}", from_agent&.name.to_s)
  end

  private

  def audit_ignored_change_keys
    super + [ "context_template" ]
  end
end
