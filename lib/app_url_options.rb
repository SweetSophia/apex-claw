module AppUrlOptions
  # Resolves externally visible app URLs with a consistent fallback chain.
  #
  # In production we avoid deriving the external host from the inbound request
  # when APP_HOST is unset, because generated URLs should come from deploy
  # configuration rather than the client-supplied Host header.
  #
  # Callers may pass any request-like object that responds to `protocol` and
  # `host_with_port`, which keeps this safe to use from controllers and helpers.
  def resolved_app_protocol(request: nil)
    ENV["APP_PROTOCOL"].presence&.delete_suffix("://") || fallback_app_protocol(request: request)
  end

  def resolved_app_host(request: nil)
    ENV["APP_HOST"].presence || fallback_app_host(request: request)
  end

  def resolved_app_base_url(request: nil)
    "#{resolved_app_protocol(request: request)}://#{resolved_app_host(request: request)}"
  end

  private

  def fallback_app_protocol(request: nil)
    return "https" if Rails.env.production?

    request&.protocol&.delete_suffix("://") || "https"
  end

  def fallback_app_host(request: nil)
    return configured_allowed_host || "apexclaw.local" if Rails.env.production?

    request&.host_with_port || configured_allowed_host || "apexclaw.local"
  end

  # Returns the first APP_ALLOWED_HOSTS entry that looks like a concrete hostname
  # suitable for outbound URL generation. Rejects wildcard/pattern entries (leading
  # dot or asterisk) that are valid for Rails host matching but not for URL building.
  def configured_allowed_host
    ENV["APP_ALLOWED_HOSTS"].to_s
      .split(",")
      .map(&:strip)
      .reject(&:empty?)
      .find { |host| !host.start_with?(".", "*") }
  end
end
