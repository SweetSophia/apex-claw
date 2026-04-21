class WorkflowsController < ApplicationController
  before_action :set_workflow, only: [:show, :update, :destroy, :run]

  def index
    @workflows = current_user.workflows.includes(:agent).recent
  end

  def show
    @runs = @workflow.workflow_runs.recent.limit(20)
  end

  def create
    @workflow = current_user.workflows.build(workflow_params)
    if @workflow.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("workflows_list", partial: "workflows/workflow_card", locals: { workflow: @workflow }) }
        format.html { redirect_to workflows_path, notice: "Workflow created" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workflow_form", partial: "workflows/form", locals: { workflow: @workflow }), status: :unprocessable_entity }
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @workflow.update(workflow_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@workflow), partial: "workflows/workflow_card", locals: { workflow: @workflow }) }
        format.html { redirect_to workflow_path(@workflow), notice: "Workflow updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workflow_form", partial: "workflows/form", locals: { workflow: @workflow }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @workflow.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@workflow)) }
      format.html { redirect_to workflows_path, notice: "Workflow deleted" }
    end
  end

  def run
    unless @workflow.runnable?
      redirect_to workflow_path(@workflow), alert: "Workflow is not runnable"
      return
    end

    workflow_run = @workflow.trigger!(trigger_type: :manual)
    if workflow_run&.persisted?
      WorkflowRunJob.perform_later(workflow_run.id)
    end
    redirect_to workflow_path(@workflow), notice: "Workflow triggered"
  end

  private

  def set_workflow
    @workflow = current_user.workflows.find(params[:id])
  end

  def workflow_params
    params.require(:workflow).permit(
      :name, :description, :agent_id,
      :trigger_type, :execution_mode, :status,
      trigger_config: {}, task_template: {}
    )
  end
end
