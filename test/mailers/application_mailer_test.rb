require "test_helper"

class ApplicationMailerTest < ActiveSupport::TestCase
  test "default_mailer_domain strips trailing port from APP_HOST" do
    original_app_host = ENV["APP_HOST"]

    ENV["APP_HOST"] = "100.111.85.48:3000"

    assert_equal "100.111.85.48", ApplicationMailer.default_mailer_domain
  ensure
    ENV["APP_HOST"] = original_app_host
  end

  test "default_mailer_domain falls back to apexclaw.local" do
    original_app_host = ENV["APP_HOST"]

    ENV.delete("APP_HOST")

    assert_equal "apexclaw.local", ApplicationMailer.default_mailer_domain
  ensure
    ENV["APP_HOST"] = original_app_host
  end
end
