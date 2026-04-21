class WorkflowRunJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 30.seconds, attempts: 1

  def perform(workflow_run_id)
    run = WorkflowRun.find_by_id(workflow_run_id)
    return unless run&.pending?

    Workflows::RunExecutor.new(run).execute!
  end
end
