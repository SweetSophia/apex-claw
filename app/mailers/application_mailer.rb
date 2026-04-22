class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "noreply@#{ENV.fetch("APP_HOST", "apexclaw.local")}")
  layout "mailer"
end
