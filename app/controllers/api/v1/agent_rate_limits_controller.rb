module Api
  module V1
    class AgentRateLimitsController < BaseController
      before_action :require_owner_token!
      before_action :set_agent

      def show
        render json: rate_limit_json(rate_limit)
      end

      def update
        if rate_limit.update(rate_limit_params)
          render json: rate_limit_json(rate_limit)
        else
          render json: { error: rate_limit.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def require_owner_token!
        return if current_user  # Allow user token
        return if current_agent && %w[show].include?(action_name)  # Allow agents to READ their own limits
        render json: { error: "Forbidden" }, status: :forbidden
      end

      def set_agent
        @agent = current_user.agents.find(params[:agent_id])
      end

      def rate_limit
        @rate_limit ||= @agent.agent_rate_limit || @agent.build_agent_rate_limit
      end

      def rate_limit_params
        params.fetch(:agent_rate_limit, ActionController::Parameters.new)
          .permit(:window_seconds, :max_requests)
      end

      def rate_limit_json(config)
        {
          agent_id: @agent.id,
          window_seconds: config.window_seconds || AgentRateLimiter::DEFAULT_WINDOW_SECONDS,
          max_requests: config.max_requests || AgentRateLimiter::DEFAULT_MAX_REQUESTS,
          created_at: config.created_at&.iso8601,
          updated_at: config.updated_at&.iso8601
        }
      end
    end
  end
end
