require "active_support/core_ext/integer/time"
require "ipaddr"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  app_host = ENV.fetch("APP_HOST", "apexclaw.local")
  app_protocol = ENV.fetch("APP_PROTOCOL", "https")
  ssl_enabled = ActiveModel::Type::Boolean.new.cast(
    ENV.fetch("APP_FORCE_SSL", (app_protocol == "https").to_s)
  )

  default_hosts = [ app_host ]
  default_hosts << "www.#{app_host}" unless app_host.start_with?("www.")
  default_hosts.concat([ "clawdeck.onrender.com", "app.clawdeck.io", ".clawdeck.io", "127.0.0.1", "::1" ])

  configured_hosts = ENV.fetch("APP_ALLOWED_HOSTS", default_hosts.join(","))
    .split(",")
    .map(&:strip)
    .reject(&:empty?)
    .uniq

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Only assume/force SSL when this deployment is actually running behind HTTPS.
  config.assume_ssl = ssl_enabled

  # Force all access to the app over SSL only when explicitly enabled.
  config.force_ssl = ssl_enabled

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Add request ID to responses for tracing
  config.action_dispatch.request_id_header = "X-Request-Id"

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Configure Action Mailer
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: app_host, protocol: app_protocol }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = configured_hosts.map do |entry|
    begin
      IPAddr.new(entry)
    rescue IPAddr::InvalidAddressError
      entry
    end
  end

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
