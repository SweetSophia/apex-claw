module Api
  module V1
    class WorkflowsController < BaseController
      before_action :set_workflow, only: [:show, :update, :destroy, :run]
      before_action :require_user_token!, only: [:create, :update, :destroy, :run]

      def index
        workflows = current_user.workflows.includes(:agent, :workflow_runs).recent
        render json: { workflows: workflows.map { |w| workflow_json(w) } }
      end

      def show
        render json: { workflow: workflow_json(@workflow, include_runs: true) }
      end

      def create
        @workflow = current_user.workflows.build(workflow_params)
        if @workflow.save
          render json: { workflow: workflow_json(@workflow) }, status: :created
        else
          render json: { error: @workflow.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        if @workflow.update(workflow_params)
          render json: { workflow: workflow_json(@workflow) }
        else
          render json: { error: @workflow.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @workflow.destroy!
        head :no_content
      end

      def run
        unless @workflow.runnable?
          render json: { error: "Workflow is not runnable" }, status: :unprocessable_entity
          return
        end

        workflow_run = @workflow.trigger!(trigger_type: :manual)

        if workflow_run&.persisted?
          WorkflowRunJob.perform_later(workflow_run.id)
          render json: { message: "Workflow triggered", run: run_json(workflow_run) }, status: :accepted
        else
          render json: { error: "Failed to trigger workflow" }, status: :unprocessable_entity
        end
      end

      private

      def set_workflow
        @workflow = current_user.workflows.find(params[:id])
      end

      def require_user_token!
        return if current_agent_token.nil?
        render json: { error: "Forbidden" }, status: :forbidden
      end

      def workflow_params
        params.require(:workflow).permit(
          :name, :description, :agent_id,
          :trigger_type, :execution_mode, :status,
          trigger_config: {}, task_template: {}
        )
      end

      def workflow_json(workflow, include_runs: false)
        json = {
          id: workflow.id,
          name: workflow.name,
          description: workflow.description,
          agent_id: workflow.agent_id,
          agent_name: workflow.agent&.name,
          trigger_type: workflow.trigger_type,
          trigger_config: workflow.trigger_config,
          execution_mode: workflow.execution_mode,
          task_template: workflow.task_template,
          status: workflow.status,
          last_run_at: workflow.last_run_at&.iso8601,
          created_at: workflow.created_at.iso8601,
          updated_at: workflow.updated_at.iso8601
        }

        if include_runs
          json[:runs] = workflow.workflow_runs.limit(20).map { |r| run_json(r) }
        end

        json
      end

      def run_json(run)
        {
          id: run.id,
          status: run.status,
          trigger_type: run.trigger_type,
          result: run.result,
          error_message: run.error_message,
          started_at: run.started_at&.iso8601,
          completed_at: run.completed_at&.iso8601,
          created_at: run.created_at.iso8601
        }
      end
    end
  end
end
