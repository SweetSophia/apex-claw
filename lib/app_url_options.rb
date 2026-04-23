module AppUrlOptions
  def resolved_app_protocol(request: nil)
    ENV["APP_PROTOCOL"].presence || request&.protocol&.delete_suffix("://") || "https"
  end

  def resolved_app_host(request: nil)
    ENV["APP_HOST"].presence || request&.host_with_port || "apexclaw.local"
  end

  def resolved_app_base_url(request: nil)
    "#{resolved_app_protocol(request: request)}://#{resolved_app_host(request: request)}"
  end
end
