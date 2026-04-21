class HandoffTemplatesController < ApplicationController
  before_action :set_template, only: [:show, :update, :destroy]

  def index
    @templates = current_user.handoff_templates.includes(:agent).recent
  end

  def show
  end

  def create
    @template = current_user.handoff_templates.build(template_params)
    if @template.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("templates_list", partial: "handoff_templates/template_card", locals: { template: @template }) }
        format.html { redirect_to handoff_templates_path, notice: "Template created" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("template_form", partial: "handoff_templates/form", locals: { template: @template }), status: :unprocessable_entity }
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @template.update(template_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@template), partial: "handoff_templates/template_card", locals: { template: @template }) }
        format.html { redirect_to handoff_template_path(@template), notice: "Template updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("template_form", partial: "handoff_templates/form", locals: { template: @template }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @template.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@template)) }
      format.html { redirect_to handoff_templates_path, notice: "Template deleted" }
    end
  end

  private

  def set_template
    @template = current_user.handoff_templates.includes(:agent).find(params[:id])
  end

  def template_params
    params.require(:handoff_template).permit(:name, :context_template, :agent_id, :auto_suggest)
  end
end
