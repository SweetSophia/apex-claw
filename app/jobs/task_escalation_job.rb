class TaskEscalationJob < ApplicationJob
  queue_as :default

  def perform
    TaskHandoffs::Escalator.escalate_blocked_tasks!
  end
end
