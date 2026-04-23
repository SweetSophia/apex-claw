require "test_helper"

class ApplicationMailerTest < ActiveSupport::TestCase
  test "default_mailer_domain strips trailing port from APP_HOST" do
    with_env("APP_HOST" => "100.111.85.48:3000") do
      assert_equal "100.111.85.48", ApplicationMailer.default_mailer_domain
    end
  end

  test "default_mailer_domain falls back to apexclaw.local" do
    with_env("APP_HOST" => nil) do
      assert_equal "apexclaw.local", ApplicationMailer.default_mailer_domain
    end
  end
end
