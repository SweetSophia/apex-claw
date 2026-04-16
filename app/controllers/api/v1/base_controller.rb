module Api
  module V1
    class BaseController < ActionController::API
      include Api::TokenAuthentication

      before_action :set_current_audit_context
      around_action :with_current_context

      rate_limit to: 60, within: 1.minute, by: -> { request.remote_ip },
        with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity

      private

      def with_current_context
        Current.set(ip_address: request.remote_ip, user_agent: request.user_agent) do
          yield
        end
      end

      def set_current_audit_context
        actor = current_agent || current_user
        Current.actor = actor
        Current.actor_type = actor&.class&.base_class&.name || "System"
        Current.actor_id = actor&.id
      end

      def not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def unprocessable_entity(exception)
        render json: { error: exception.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end
  end
end
