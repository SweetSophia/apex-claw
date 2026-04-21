module Api
  module V1
    class InvalidJsonError < StandardError; end

    class AgentsController < BaseController
      MIN_HEARTBEAT_INTERVAL = 5
      MAX_HEARTBEAT_INTERVAL = 300

      skip_before_action :authenticate_api_token, only: :register
      before_action :set_agent, only: [ :show, :update, :rotate_token, :revoke_token, :archive, :restore, :tasks ]
      before_action :set_agent_for_heartbeat, only: [ :heartbeat ]
      before_action :require_current_agent!, only: :heartbeat
      before_action :require_agent_self!, only: :heartbeat
      before_action :require_owner_user!, only: [ :update, :rotate_token, :revoke_token, :archive, :restore, :tasks ]
      before_action :require_user_token!, only: [ :update, :archive, :restore, :tasks ]

      rescue_from InvalidJsonError, with: :json_parse_error

      def register
        join_token = JoinToken.consume!(register_join_token)
        unless join_token
          render json: { error: "Invalid join token" }, status: :unauthorized
          return
        end

        agent = join_token.user.agents.new(register_params)
        if agent.save
          _agent_token, plaintext_token = AgentToken.issue!(agent: agent, name: "Bootstrap")
          render json: { agent: agent_json(agent), agent_token: plaintext_token }, status: :created
        else
          render json: { error: agent.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def heartbeat
        updates = {
          last_heartbeat_at: Time.current,
          status: params[:status].presence || :online
        }
        updates[:version] = params[:version] if params.key?(:version)
        updates[:platform] = params[:platform] if params.key?(:platform)
        updates[:metadata] = params[:metadata] if params.key?(:metadata)

        @agent.update!(updates)
        render json: {
          agent: agent_json(@agent),
          desired_state: { action: "none" },
          token_rotation_required: current_agent_token&.expires_soon? || false,
          heartbeat_interval_seconds: heartbeat_interval_seconds
        }
      end

      def rotate_token
        new_plaintext_token = nil
        current_token = @agent.agent_tokens.active.order(created_at: :desc).first
        expires_at = current_token&.expires_at

        AgentToken.transaction do
          current_token&.update!(revoked_at: Time.current)
          _rotated_token, new_plaintext_token = AgentToken.issue!(
            agent: @agent,
            name: "Rotated",
            expires_at: expires_at
          )
        end

        render json: {
          agent: agent_json(@agent),
          agent_token: new_plaintext_token
        }, status: :created
      end

      def revoke_token
        revoked_at = Time.current
        revoked_count = @agent.agent_tokens.active.update_all(revoked_at: revoked_at, updated_at: revoked_at)

        render json: {
          agent: agent_json(@agent),
          revoked_tokens: revoked_count
        }
      end

      def archive
        if @agent.archived?
          render json: { error: "Agent is already archived" }, status: :unprocessable_entity
          return
        end
        @agent.archive!(current_user)
        render json: agent_json(@agent)
      end

      def restore
        if !@agent.archived?
          render json: { error: "Agent is not archived" }, status: :unprocessable_entity
          return
        end
        @agent.restore!
        render json: agent_json(@agent)
      end

      def tasks
        claimed = @agent.claimed_tasks
          .includes(:board)
          .order(Arel.sql("CASE WHEN status = 'done' THEN 1 ELSE 0 END, completed_at DESC NULLS LAST, updated_at DESC"))
          .limit(50)
        assigned = @agent.assigned_tasks
          .where.not(id: claimed.select(:id))
          .includes(:board)
          .order(updated_at: :desc)
          .limit(50)

        render json: {
          claimed: claimed.map { |t| task_json(t) },
          assigned: assigned.map { |t| task_json(t) }
        }
      end

      def index
        agents = if params[:include_archived] == "true"
          current_user.agents
        else
          current_user.agents.active
        end.order(created_at: :desc)
        render json: agents.map { |agent| agent_json(agent) }
      end

      def show
        render json: agent_json(@agent)
      end

      def update
        if @agent.update(update_params)
          render json: agent_json(@agent)
        else
          render json: { error: @agent.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      private

      def set_agent
        @agent = Agent.find(params[:id])
      end

      def set_agent_for_heartbeat
        @agent = Agent.find(params[:id])
      end

      def require_current_agent!
        return if current_agent

        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def require_agent_self!
        return if current_agent.id == @agent.id

        render json: { error: "Forbidden" }, status: :forbidden
      end

      # Verifies the authenticated identity is allowed to access @agent.
      # Agent tokens may only manage the agent they belong to (no sibling access).
      # User tokens may manage any agent belonging to the user.
      def require_owner_user!
        if current_agent_token.present?
          return if current_agent.id == @agent.id
        else
          return if @agent.user_id == current_user.id
        end
        render json: { error: "Forbidden" }, status: :forbidden
      end

      # Restricts the action to user-token auth only (blocks agent tokens).
      def require_user_token!
        return if current_agent_token.nil?

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def register_join_token
        params[:join_token] || params.dig(:agent, :join_token)
      end

      def register_params
        p = params.fetch(:agent, ActionController::Parameters.new).permit(
          :name, :hostname, :host_uid, :platform, :version,
          :instructions, :model, :max_concurrent_tasks,
          :custom_env, :custom_args,
          tags: [], metadata: {}
        )
        parse_json_fields(p)
        p
      end

      def update_params
        p = params.fetch(:agent, ActionController::Parameters.new).permit(
          :name, :status,
          :instructions, :model, :max_concurrent_tasks,
          :custom_env, :custom_args,
          tags: [], metadata: {}
        )
        parse_json_fields(p)
        p
      end

      # Parse JSON-encoded string values for custom_env and custom_args.
      # Accepts either a pre-parsed Hash/Array (from other clients) or a
      # JSON string (from the web UI form fields).
      # Returns a hard 422 on invalid JSON instead of silently defaulting.
      def parse_json_fields(p)
        %i[custom_env custom_args].each do |key|
          val = p[key]
          next if val.nil?
          p[key] = case val
            when Hash then val
            when Array then val
            when String
              val.strip.empty? ? (key == :custom_env ? {} : []) : JSON.parse(val)
            else {}
          end
        rescue JSON::ParserError
          raise InvalidJsonError
        end
      end

      def json_parse_error
        render json: { error: 'Invalid JSON format' }, status: :unprocessable_entity
      end

      def heartbeat_interval_seconds
        ENV.fetch("CLAWDECK_HEARTBEAT_INTERVAL_SECONDS", 30).to_i.clamp(MIN_HEARTBEAT_INTERVAL, MAX_HEARTBEAT_INTERVAL)
      end

      def agent_json(agent)
        {
          id: agent.id,
          user_id: agent.user_id,
          name: agent.name,
          status: agent.status,
          hostname: agent.hostname,
          host_uid: agent.host_uid,
          platform: agent.platform,
          version: agent.version,
          tags: agent.tags || [],
          metadata: agent.metadata || {},
          instructions: agent.instructions,
          custom_env: agent.custom_env || {},
          custom_args: agent.custom_args || [],
          model: agent.model,
          max_concurrent_tasks: agent.max_concurrent_tasks,
          archived_at: agent.archived_at&.iso8601,
          last_heartbeat_at: agent.last_heartbeat_at&.iso8601,
          created_at: agent.created_at.iso8601,
          updated_at: agent.updated_at.iso8601
        }
      end

      def task_json(task)
        {
          id: task.id,
          name: task.name,
          status: task.status,
          priority: task.priority,
          board_id: task.board_id,
          board_name: task.board.name,
          completed_at: task.completed_at&.iso8601,
          updated_at: task.updated_at.iso8601,
          created_at: task.created_at.iso8601
        }
      end
    end
  end
end
