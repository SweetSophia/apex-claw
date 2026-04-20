# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.config.content_security_policy do |policy|
  # Default-src
  policy.default_src :self

  # Rails defaults
  policy.connect_src :self, :https, mode: :crawl

  # Asset hosting (CDN or asset pipeline)
  policy.asset_src :self

  # Images
  policy.img_src :self, :data, :https

  # Scripts — only from self and any CDN pinned in importmap
  policy.script_src :self, :unsafe_inline  # needed for Stimulus inline handlers

  # Styles — only from self (Tailwind uses self)
  policy.style_src :self, :unsafe_inline  # needed for Stimulus inline styles

  # Frames — none
  policy.frame_src :none

  # Form action
  policy.form_action :self

  # Upgrade insecure requests in production
  policy.upgrade_insecure_requests :always if Rails.env.production?
end

Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
