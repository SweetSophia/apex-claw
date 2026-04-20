class AgentRateLimiter
  DEFAULT_WINDOW_SECONDS = 60
  DEFAULT_MAX_REQUESTS = 120
  CACHE_KEY_PREFIX = "agent_rate_limit"

  def initialize(app)
    @app = app
  end

  def call(env)
    token = extract_token(env["HTTP_AUTHORIZATION"])
    agent_token = AgentToken.authenticate(token)
    return @app.call(env) unless agent_token

    agent = agent_token.agent
    env["clawdeck.current_agent"] = agent
    env["clawdeck.current_user"] = agent.user

    rate_limit = agent.agent_rate_limit
    window_seconds = rate_limit&.window_seconds || DEFAULT_WINDOW_SECONDS
    max_requests = rate_limit&.max_requests || DEFAULT_MAX_REQUESTS

    now = Time.current.to_i
    window_start = now - (now % window_seconds)
    reset_at = window_start + window_seconds
    cache_key = "#{CACHE_KEY_PREFIX}:#{agent.id}:#{window_start}"
    request_count = increment_counter(cache_key, expires_in: window_seconds.seconds)

    headers = rate_limit_headers(
      limit: max_requests,
      remaining: [ max_requests - request_count, 0 ].max,
      reset_at: reset_at
    )

    if request_count > max_requests
      return rate_limited_response(headers, reset_at: reset_at, now: now)
    end

    status, response_headers, body = @app.call(env)
    [ status, response_headers.merge(headers), body ]
  end

  private

  def extract_token(auth_header)
    return nil if auth_header.blank?

    auth_header[/\ABearer\s+(.+)\z/i, 1]
  end

  def increment_counter(key, expires_in:)
    now = Time.current.to_i
    expires_at_value = now + expires_in.to_i

    result = ActiveRecord::Base.connection.execute(sanitize_sql([
      "INSERT INTO counters (key, count, expires_at, created_at, updated_at)
       VALUES (?, 1, ?, NOW(), NOW())
       ON CONFLICT (key) DO UPDATE SET
         count = counters.count + 1,
         updated_at = NOW()
       WHERE counters.expires_at > ?",
      key, expires_at_value, now
    ]))

    # Read back the current count
    row = ActiveRecord::Base.connection.execute(
      sanitize_sql(["SELECT count FROM counters WHERE key = ?", key])
    ).first
    row ? row["count"].to_i : 1
  rescue ActiveRecord::StatementInvalid
    # Fallback for DB errors - allow request
    1
  end

  def sanitize_sql(sql)
    ActiveRecord::Base.send(:sanitize_sql_array, sql)
  end

  def rate_limit_headers(limit:, remaining:, reset_at:)
    {
      "X-RateLimit-Limit" => limit.to_s,
      "X-RateLimit-Remaining" => remaining.to_s,
      "X-RateLimit-Reset" => reset_at.to_s
    }
  end

  def rate_limited_response(headers, reset_at:, now:)
    retry_after = [ reset_at - now, 1 ].max
    body = { error: "Rate limit exceeded" }.to_json

    [
      429,
      headers.merge(
        "Content-Type" => "application/json",
        "Content-Length" => body.bytesize.to_s,
        "Retry-After" => retry_after.to_s
      ),
      [ body ]
    ]
  end
end
