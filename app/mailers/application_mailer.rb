class ApplicationMailer < ActionMailer::Base
  def self.default_mailer_domain
    host = ENV.fetch("APP_HOST", "apexclaw.local")
    host.sub(%r{:\d+\z}, "")
  end

  default from: ENV.fetch("MAILER_FROM", "noreply@#{self.default_mailer_domain}")
  layout "mailer"
end
