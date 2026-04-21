module Workflows
  class RunExecutor
    def initialize(workflow_run)
      @run = workflow_run
      @workflow = workflow_run.workflow
    end

    def execute!
      mark_running

      case @workflow.execution_mode
      when "create_task"
        create_task_and_assign
      when "run_only"
        mark_completed(result: { message: "Workflow executed in run_only mode" })
      end
    rescue => e
      mark_failed(e.message)
    end

    private

    def create_task_and_assign
      agent = @workflow.agent
      unless agent&.active_for_work?
        mark_failed("Agent is not available for work")
        return
      end

      template = @workflow.task_template
      task_name = template["name"] || @workflow.name
      task_description = template["description"] || @workflow.description

      board = agent.user.boards.first
      unless board
        mark_failed("No board available for task creation")
        return
      end

      task = Task.create!(
        user: agent.user,
        board: board,
        name: task_name,
        description: task_description,
        status: :up_next,
        assigned_agent: agent
      )
      task.assign_to_agent!

      mark_completed(result: { task_id: task.id, task_name: task.name })
    end

    def mark_running
      @run.update!(status: :running, started_at: Time.current)
    end

    def mark_completed(result:)
      @run.update!(
        status: :completed,
        result: result,
        completed_at: Time.current
      )
      @workflow.update!(last_run_at: Time.current)
    end

    def mark_failed(message)
      @run.update!(
        status: :failed,
        error_message: message,
        completed_at: Time.current
      )
    end
  end
end
