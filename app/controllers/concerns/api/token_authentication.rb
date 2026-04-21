module Api
  module TokenAuthentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_api_token
      after_action :track_api_usage
      attr_reader :current_user, :current_agent, :current_agent_token
    end

    private

    def authenticate_api_token
      token = extract_token_from_header
      @current_agent = request.env["clawdeck.current_agent"]
      @current_user = request.env["clawdeck.current_user"]
      @current_agent_token = nil

      agent_token = AgentToken.authenticate(token)

      if @current_agent
        @current_agent_token = agent_token if agent_token&.agent_id == @current_agent.id
      elsif agent_token
        @current_agent_token = agent_token
        @current_agent = agent_token.agent
        @current_user = @current_agent.user
      else
        @current_agent = nil
        @current_user = ApiToken.authenticate(token)
      end

      unless @current_user
        render json: { error: "Unauthorized" }, status: :unauthorized
        return
      end

      update_agent_info_from_headers if @current_agent.nil?
    end

    def extract_token_from_header
      auth_header = request.headers["Authorization"]
      return nil unless auth_header

      match = auth_header.match(/\ABearer\s+(.+)\z/i)
      match&.[](1)
    end

    def track_api_usage
      ApiUsageRecord.track!(current_user) if current_user
    end

    def update_agent_info_from_headers
      return unless @current_user
      return if @current_agent.present?

      updates = {}
      agent_name = request.headers["X-Agent-Name"].presence
      agent_emoji = request.headers["X-Agent-Emoji"].presence
      updates[:agent_name] = agent_name if agent_name
      updates[:agent_emoji] = agent_emoji if agent_emoji

      @current_user.update_columns(updates) if updates.any?
    end
  end
end
