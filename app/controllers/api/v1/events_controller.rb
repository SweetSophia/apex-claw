module Api
  module V1
    class EventsController < BaseController
      include ActionController::Live

      # GET /api/v1/events — Server-Sent Events stream
      def index
        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"

        channel = "api:events:#{current_user.id}"

        # Send initial connection event
        sse_write({
          type: "connection.established",
          data: { user_id: current_user.id },
          timestamp: Time.current.utc.iso8601
        })

        # Subscribe to the cable channel for real-time events
        subscription = subscribe_to_channel(channel)

        # Heartbeat to keep connection alive and detect disconnects
        heartbeat_interval = 15
        last_heartbeat = Time.current

        # Block until client disconnects
        loop do
          sleep 0.5

          # Send heartbeat every 15 seconds
          if Time.current - last_heartbeat >= heartbeat_interval
            sse_write({ type: "heartbeat", data: {}, timestamp: Time.current.utc.iso8601 })
            last_heartbeat = Time.current
          end
        end
      rescue IOError, ClientDisconnected
        # Client disconnected — this is normal
      ensure
        unsubscribe_from_channel(channel, subscription) if subscription
        response.stream.close unless response.stream.closed?
      end

      private

      def subscribe_to_channel(channel)
        callback = ->(message) do
          data = message.is_a?(String) ? message : message.to_json
          sse_write(data)
        end
        ActionCable.server.pubsub.subscribe(channel, callback)
      end

      def unsubscribe_from_channel(channel, subscription)
        ActionCable.server.pubsub.unsubscribe(channel, subscription)
      end

      def sse_write(data)
        json = data.is_a?(String) ? data : data.to_json
        response.stream.write("data: #{json}\n\n")
      rescue IOError
        # Stream already closed — client disconnected
      end
    end
  end
end
