class RoutingRulesController < ApplicationController
  before_action :set_rule, only: [:show, :update, :destroy]

  def index
    @rules = current_user.routing_rules.includes(:agent).by_priority
  end

  def show
  end

  def create
    @rule = current_user.routing_rules.build(rule_params)
    if @rule.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("rules_list", partial: "routing_rules/rule_card", locals: { rule: @rule }) }
        format.html { redirect_to routing_rules_path, notice: "Routing rule created" }
      end
    else
      @rules = current_user.routing_rules.includes(:agent).by_priority
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("rule_form", partial: "routing_rules/form", locals: { rule: @rule, agents: current_user.agents.active }), status: :unprocessable_entity }
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @rule.update(rule_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@rule), partial: "routing_rules/rule_card", locals: { rule: @rule }) }
        format.html { redirect_to routing_rule_path(@rule), notice: "Routing rule updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("rule_form", partial: "routing_rules/form", locals: { rule: @rule, agents: current_user.agents.active }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @rule.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@rule)) }
      format.html { redirect_to routing_rules_path, notice: "Routing rule deleted" }
    end
  end

  private

  def set_rule
    @rule = current_user.routing_rules.includes(:agent).find(params[:id])
  end

  def rule_params
    permitted = params.require(:routing_rule).permit(:name, :priority, :agent_id, :active, conditions: {})

    if permitted.key?(:conditions)
      conditions = permitted[:conditions].to_h

      %w[priority status].each do |key|
        conditions[key] = conditions[key].to_s.strip if conditions.key?(key)
      end

      %w[tags skills].each do |key|
        next unless conditions.key?(key)

        conditions[key] = conditions[key].to_s.split(",").map(&:strip).reject(&:blank?)
      end

      conditions.delete_if { |_, value| value.blank? }
      permitted[:conditions] = conditions
    end

    permitted
  end
end
