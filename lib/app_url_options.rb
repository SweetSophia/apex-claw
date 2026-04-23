require "ipaddr"

module AppUrlOptions
  # Resolves externally visible app URLs with a consistent fallback chain.
  #
  # In production we avoid deriving the external host or protocol from the
  # inbound request when APP_HOST or APP_PROTOCOL is unset, because generated
  # URLs should come from deploy configuration rather than client-supplied
  # request metadata.
  #
  # Callers may pass any request-like object that responds to `protocol` and
  # `host_with_port`, which keeps this safe to use from controllers and helpers.
  #
  # Keep the distinction between the host helpers clear:
  # - `resolved_app_host` returns the canonical host value without URL-only
  #   transformations so callers can still inspect or compare the raw host.
  # - `resolved_app_url_host` returns a host that is safe to embed in absolute
  #   URLs, including bracketed IPv6 literals.

  # Returns the externally visible protocol without a trailing `://`.
  #
  # Resolution order:
  # 1. `APP_PROTOCOL`, normalized to strip any accidental scheme suffix
  # 2. non-production request protocol when available
  # 3. hard fallback (`https` in all environments)
  def resolved_app_protocol(request: nil)
    ENV["APP_PROTOCOL"].presence&.delete_suffix("://") || fallback_app_protocol(request: request)
  end

  # Returns the canonical host value for the app.
  #
  # This preserves the raw configured host so non-URL callers do not pick up
  # URL-specific formatting such as IPv6 brackets.
  def resolved_app_host(request: nil)
    ENV["APP_HOST"].presence || fallback_app_host(request: request)
  end

  # Returns a host value that is safe to interpolate into absolute URLs.
  #
  # IPv6 literals are bracketed here so Rails URL helpers and manual URL
  # interpolation both produce valid authorities.
  def resolved_app_url_host(request: nil)
    format_host_for_url(resolved_app_host(request: request))
  end

  # Returns the full externally visible base URL used by helpers and API output.
  def resolved_app_base_url(request: nil)
    "#{resolved_app_protocol(request: request)}://#{resolved_app_url_host(request: request)}"
  end

  private

  # Production never trusts the inbound request protocol for outbound URLs.
  # Other environments may fall back to the request when `APP_PROTOCOL` is unset.
  def fallback_app_protocol(request: nil)
    return "https" if Rails.env.production?

    request&.protocol&.delete_suffix("://") || "https"
  end

  # Production falls back only to deploy-time host config, never to the request.
  # Other environments may use the current request host for local convenience.
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

  # Formats a host for URL usage without changing ordinary DNS names.
  #
  # Already-bracketed IPv6 literals pass through unchanged, which keeps the
  # transformation idempotent when callers or environment config already include
  # brackets.
  def format_host_for_url(host)
    return host if host.blank? || host.start_with?("[")
    return "[#{host}]" if ipv6_literal?(host)

    host
  end

  # Detects bare IPv6 literals while ignoring normal hostnames and host:port strings
  # that are already valid authorities for URL generation.
  def ipv6_literal?(host)
    return false unless host.include?(":")

    IPAddr.new(host).ipv6?
  rescue IPAddr::InvalidAddressError
    false
  end
end
