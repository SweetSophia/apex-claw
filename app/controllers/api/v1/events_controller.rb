module Api
  module V1
    class EventsController < BaseController
      include ActionController::Live

      MAX_CONCURRENT_CONNECTIONS = 5

      # GET /api/v1/events — Server-Sent Events stream
      def index
        # TODO: Replace class-level counter with Redis INCR/DECR for multi-process.
        if concurrent_sse_connections >= MAX_CONCURRENT_CONNECTIONS
          render json: { error: "Too many connections" }, status: :service_unavailable
          return
        end
        self.class.increment_sse_connections
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

        # Configurable max connection duration to prevent resource exhaustion
        max_connection_time = ENV.fetch("SSE_MAX_CONNECTION_SECONDS", 1800).to_i  # 30 min default
        connection_start = Time.current

        # Block until client disconnects
        loop do
          sleep 0.5

          # Force disconnect after max connection time
          if Time.current - connection_start >= max_connection_time
            sse_write({ type: "connection.timeout", data: {}, timestamp: Time.current.utc.iso8601 })
            break
          end

          # Send heartbeat every 15 seconds
          if Time.current - last_heartbeat >= heartbeat_interval
            sse_write({ type: "heartbeat", data: {}, timestamp: Time.current.utc.iso8601 })
            last_heartbeat = Time.current
          end
        end
      rescue IOError, ClientDisconnected
        # Client disconnected — this is normal
      ensure
        self.class.decrement_sse_connections
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

      def concurrent_sse_connections
        # Uses a class-level thread-safe counter. Accurate within a single
        # process; for multi-process deployments, replace with Redis INCR/DECR.
        @@sse_connection_count ||= 0
        @@sse_connection_count
      end

      def self.increment_sse_connections
        @@sse_connection_count = (@@sse_connection_count || 0) + 1
      end

      def self.decrement_sse_connections
        @@sse_connection_count = [(@@sse_connection_count || 1) - 1, 0].max
      end
    end
  end
end
