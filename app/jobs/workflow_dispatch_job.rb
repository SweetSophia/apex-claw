class WorkflowDispatchJob < ApplicationJob
  queue_as :default

  def perform
    Workflow.active.where(trigger_type: :schedule).find_each do |workflow|
      next unless workflow.runnable?
      next unless due?(workflow)

      workflow_run = workflow.trigger!(trigger_type: :schedule)
      WorkflowRunJob.perform_later(workflow_run.id) if workflow_run&.persisted?
    end
  end

  private

  def due?(workflow)
    cron = workflow.trigger_config["cron"]
    return false unless cron.present?

    interval = parse_cron_to_interval(cron)
    if interval.nil?
      Rails.logger.warn "Workflow #{workflow.id} has unparseable cron schedule: #{cron.inspect}"
      return false
    end

    workflow.last_run_at.nil? || workflow.last_run_at < interval.ago
  end

  # Simple cron-to-interval: supports "every N minutes/hours" patterns
  # Full cron parsing can be added later with the `fugit` gem
  def parse_cron_to_interval(cron)
    case cron
    when /\Aevery (\d+) minutes?\z/i
      $1.to_i.minutes
    when /\Aevery (\d+) hours?\z/i
      $1.to_i.hours
    when /\A(\d+)m\z/
      $1.to_i.minutes
    when /\A(\d+)h\z/
      $1.to_i.hours
    else
      nil
    end
  end
end
