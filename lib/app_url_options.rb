module AppUrlOptions
  # Resolves externally visible app URLs with a consistent fallback chain:
  # ENV override -> request-derived value -> hardcoded local default.
  # Callers may pass any request-like object that responds to `protocol` and
  # `host_with_port`, which keeps this safe to use from controllers and helpers.
  def resolved_app_protocol(request: nil)
    ENV["APP_PROTOCOL"].presence&.delete_suffix("://") || request&.protocol&.delete_suffix("://") || "https"
  end

  def resolved_app_host(request: nil)
    ENV["APP_HOST"].presence || request&.host_with_port || "apexclaw.local"
  end

  def resolved_app_base_url(request: nil)
    "#{resolved_app_protocol(request: request)}://#{resolved_app_host(request: request)}"
  end
end
