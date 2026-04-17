module Api
  module V1
    class TaskHandoffsController < BaseController
      include Broadcastable
      before_action :require_current_agent!
      before_action :set_handoff, only: [ :accept, :reject ]

      # GET /api/v1/task_handoffs
      def index
        scope = TaskHandoff.for_agent(current_agent.id)

        if params[:status].present? && TaskHandoff.statuses.key?(params[:status])
          scope = scope.where(status: params[:status])
        end

        if params[:task_id].present?
          scope = scope.for_task(params[:task_id])
        end

        limit = (params[:limit] || 20).to_i.clamp(1, 100)
        offset = (params[:offset] || 0).to_i

        @handoffs = scope.order(created_at: :desc).limit(limit).offset(offset)
        render json: @handoffs.map { |h| handoff_json(h) }
      end

      # POST /api/v1/tasks/:id/handoff
      def create
        @task = current_user.tasks.find(params[:id])

        # Only the currently assigned/claiming agent can initiate
        unless @task.assigned_agent_id == current_agent.id || @task.claimed_by_agent_id == current_agent.id
          render json: { error: "Only the assigned or claiming agent can initiate a handoff" }, status: :forbidden
          return
        end

        target_agent = current_user.agents.find(params[:to_agent_id])

        handoff = TaskHandoff.new(
          task: @task,
          from_agent: current_agent,
          to_agent: target_agent,
          context: params[:context]
        )

        if params[:auto_accept].present? && ActiveModel::Type::Boolean.new.cast(params[:auto_accept])
          handoff.status = :accepted
          handoff.responded_at = Time.current
        end

        @task.with_lock do
          if @task.handoffs.pending.exists?
            render json: { error: "Task already has a pending handoff" }, status: :unprocessable_entity
            return
          end

          ApplicationRecord.transaction do
            handoff.save!

            if handoff.accepted?
              reassign_task_to_agent(@task, target_agent)
              record_handoff_activity(@task, handoff, "accepted")
            end
          end
        end

        render json: handoff_json(handoff), status: :created
      end

      # PATCH /api/v1/task_handoffs/:id/accept
      def accept
        unless @handoff.to_agent_id == current_agent.id
          render json: { error: "Only the target agent can accept this handoff" }, status: :forbidden
          return
        end

        unless @handoff.pending?
          render json: { error: "Handoff is no longer pending" }, status: :unprocessable_entity
          return
        end

        @handoff.with_lock do
          unless @handoff.pending?
            render json: { error: "Handoff is no longer pending" }, status: :unprocessable_entity
            return
          end

          ApplicationRecord.transaction do
            @handoff.accept!
            reassign_task_to_agent(@handoff.task, @handoff.to_agent)
            record_handoff_activity(@handoff.task, @handoff, "accepted")
          end
        end

        # Broadcast task update to board
        broadcast_task_event(@handoff.task, type: "task.updated")

        render json: handoff_json(@handoff)
      end

      # PATCH /api/v1/task_handoffs/:id/reject
      def reject
        unless @handoff.to_agent_id == current_agent.id
          render json: { error: "Only the target agent can reject this handoff" }, status: :forbidden
          return
        end

        unless @handoff.pending?
          render json: { error: "Handoff is no longer pending" }, status: :unprocessable_entity
          return
        end

        @handoff.with_lock do
          unless @handoff.pending?
            render json: { error: "Handoff is no longer pending" }, status: :unprocessable_entity
            return
          end

          ApplicationRecord.transaction do
            @handoff.reject!
            record_handoff_activity(@handoff.task, @handoff, "rejected")
          end
        end

        render json: handoff_json(@handoff)
      end

      private

      def require_current_agent!
        return if current_agent

        render json: { error: "Agent authentication required" }, status: :unauthorized
      end

      def set_handoff
        @handoff = TaskHandoff
          .joins(:task)
          .where(tasks: { user_id: current_user.id })
          .find(params[:id])
      end

      def reassign_task_to_agent(task, agent)
        set_task_activity_info(task)
        task.update!(
          assigned_agent: agent,
          claimed_by_agent: agent,
          agent_claimed_at: Time.current
        )
      end

      def record_handoff_activity(task, handoff, action)
        TaskActivity.create!(
          task: task,
          user: current_user,
          actor_agent: current_agent,
          action: "updated",
          field_name: "handoff",
          old_value: handoff.from_agent.name,
          new_value: handoff.to_agent.name,
          source: "api",
          actor_type: "agent",
          actor_name: current_agent.name,
          note: "Handoff #{action}: #{handoff.context&.truncate(100)}"
        )
      end

      def set_task_activity_info(task)
        task.activity_source = "api"
        task.actor_user = current_user
        task.actor_agent = current_agent
        task.actor_name = current_agent.name
      end

      def handoff_json(handoff)
        {
          id: handoff.id,
          task_id: handoff.task_id,
          from_agent_id: handoff.from_agent_id,
          to_agent_id: handoff.to_agent_id,
          context: handoff.context,
          status: handoff.status,
          responded_at: handoff.responded_at&.iso8601,
          created_at: handoff.created_at.iso8601,
          updated_at: handoff.updated_at.iso8601
        }
      end
    end
  end
end
