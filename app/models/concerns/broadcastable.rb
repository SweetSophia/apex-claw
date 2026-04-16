# Broadcastable concern — real-time Turbo Stream + SSE helpers
#
# Included by controllers that need to push live updates.
# The Task model already handles its own broadcasts via callbacks;
# this concern adds:
#   • broadcast_task_event — fires SSE events to API consumers
#   • broadcast_agent_status — pushes agent card updates to dashboard
module Broadcastable
  extend ActiveSupport::Concern

  included do
    # Make Turbo::StreamsChannel available in controllers
  end

  private

  # Broadcast a task-related event to SSE subscribers for the task's owner.
  # type: event name (e.g. "task.created", "task.completed")
  def broadcast_task_event(task, type:)
    return unless task&.user_id

    payload = {
      type: type,
      data: {
        id: task.id,
        name: task.name,
        status: task.status,
        priority: task.priority,
        board_id: task.board_id,
        completed: task.completed,
        assigned_agent_id: task.assigned_agent_id,
        claimed_by_agent_id: task.claimed_by_agent_id
      },
      timestamp: Time.current.utc.iso8601
    }

    Turbo::StreamsChannel.broadcast_action_to(
      "api:events:#{task.user_id}",
      action: :append,
      target: "sse-events",
      html: "" # unused — the real payload is sent via the SSE channel subscription
    )

    # Direct SSE broadcast through a dedicated channel
    ActionCable.server.broadcast("api:events:#{task.user_id}", payload.to_json)
  end

  # Broadcast agent status change to the "agents" Turbo Stream channel
  # so the agents index page updates live.
  def broadcast_agent_status(agent)
    return unless agent&.user_id

    # Broadcast to the user's agents stream for dashboard updates
    Turbo::StreamsChannel.broadcast_action_to(
      "agents:#{agent.user_id}",
      action: :replace,
      target: "agent_#{agent.id}",
      partial: "agents/agent_card",
      locals: { agent: agent }
    )
  end
end
