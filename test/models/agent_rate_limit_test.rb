require "test_helper"

class AgentRateLimitTest < ActiveSupport::TestCase
  setup do
    @agent = Agent.create!(user: users(:one), name: "Rate Limited Worker")
  end

  test "is valid with defaults" do
    rate_limit = AgentRateLimit.new(agent: @agent)

    assert rate_limit.valid?
    assert_equal 60, rate_limit.window_seconds
    assert_equal 120, rate_limit.max_requests
  end

  test "requires positive integer values" do
    rate_limit = AgentRateLimit.new(agent: @agent, window_seconds: 0, max_requests: -1)

    assert_not rate_limit.valid?
    assert_includes rate_limit.errors[:window_seconds], "must be greater than 0"
    assert_includes rate_limit.errors[:max_requests], "must be greater than 0"
  end
end
