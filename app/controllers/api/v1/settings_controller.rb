module Api
  module V1
    class SettingsController < BaseController
      # GET /api/v1/settings - get current user's agent settings
      def show
        render json: settings_json
      end

      # PATCH /api/v1/settings - update agent settings
      def update
        if current_user.update(settings_params)
          render json: settings_json
        else
          render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def settings_params
        params.permit(:agent_name, :agent_emoji, :agent_auto_mode, :theme_preference)
      end

      def settings_json
        {
          agent_auto_mode: current_user.agent_auto_mode,
          agent_status: agent_status,
          registered_agents_count: current_user.agents.count,
          email: current_user.email_address,
          theme_preference: current_user.theme_preference
        }
      end

      def agent_status
        return "not_configured" unless current_user.agents.exists?

        current_user.agents.where(status: :online).exists? ? "online" : "offline"
      end
    end
  end
end
