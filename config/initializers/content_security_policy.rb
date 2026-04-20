# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

ssl_enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("APP_FORCE_SSL", ENV.fetch("APP_PROTOCOL", "https") == "https" ? "true" : "false")
)

Rails.application.config.content_security_policy do |policy|
  # Default-src
  policy.default_src :self

  # Rails defaults
  policy.connect_src :self, :https

  # Fonts
  policy.font_src :self

  # Images
  policy.img_src :self, :data, :https

  # Scripts — nonces auto-applied via content_security_policy_nonce_generator
  # Stimulus controllers loaded via importmap use nonces, no unsafe-inline needed
  policy.script_src :self

  # Styles — Tailwind via asset pipeline uses self, inline styles use nonces
  policy.style_src :self

  # Frames — none
  policy.frame_src :none

  # Form action
  policy.form_action :self

  # Upgrade insecure requests only for real HTTPS deployments.
  policy.upgrade_insecure_requests :always if Rails.env.production? && ssl_enabled
end

Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
