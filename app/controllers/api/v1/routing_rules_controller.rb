module Api
  module V1
    class RoutingRulesController < BaseController
      before_action :set_rule, only: [ :show, :update, :destroy ]
      before_action :require_user_token!, only: [ :create, :update, :destroy ]

      def index
        rules = current_user.routing_rules.includes(:agent).by_priority
        render json: { rules: rules.map { |r| rule_json(r) } }
      end

      def show
        render json: { rule: rule_json(@rule) }
      end

      def create
        @rule = current_user.routing_rules.build(rule_params)
        if @rule.save
          render json: { rule: rule_json(@rule) }, status: :created
        else
          render json: { error: @rule.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        if @rule.update(rule_params)
          render json: { rule: rule_json(@rule) }
        else
          render json: { error: @rule.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @rule.destroy!
        head :no_content
      end

      private

      def set_rule
        @rule = current_user.routing_rules.find(params[:id])
      end

      def require_user_token!
        return if current_agent_token.nil?
        render json: { error: "Forbidden" }, status: :forbidden
      end

      def rule_params
        params.require(:routing_rule).permit(:name, :priority, :agent_id, :active, conditions: {})
      end

      def rule_json(rule)
        {
          id: rule.id,
          name: rule.name,
          priority: rule.priority,
          conditions: rule.conditions,
          agent_id: rule.agent_id,
          agent_name: rule.agent&.name,
          active: rule.active,
          created_at: rule.created_at.iso8601,
          updated_at: rule.updated_at.iso8601
        }
      end
    end
  end
end
