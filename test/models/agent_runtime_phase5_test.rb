require "test_helper"

class AgentRuntimePhase5Test < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:one)
  end

  test "runtime_provider falls back from metadata provider to model to OpenClaw" do
    metadata_provider_agent = create_agent(
      suffix: "provider",
      metadata: { "provider" => "Anthropic" },
      model: "Claude Sonnet"
    )
    model_agent = create_agent(suffix: "model", metadata: {}, model: "GPT-4.1")
    default_agent = create_agent(suffix: "default", metadata: {}, model: nil)

    assert_equal "Anthropic", metadata_provider_agent.runtime_provider
    assert_equal "GPT-4.1", model_agent.runtime_provider
    assert_equal "OpenClaw", default_agent.runtime_provider
  end

  test "last_seen_label returns never and recent heartbeat values" do
    never_seen = create_agent(suffix: "never", last_heartbeat_at: nil)

    assert_equal "Never", never_seen.last_seen_label

    travel_to Time.zone.local(2026, 4, 21, 12, 0, 0) do
      recent = create_agent(suffix: "recent", last_heartbeat_at: 2.minutes.ago)

      assert_equal "2 minutes ago", recent.last_seen_label
    end
  end

  test "last_seen_state returns never stale and live" do
    never_seen = create_agent(suffix: "never-state", last_heartbeat_at: nil)

    travel_to Time.zone.local(2026, 4, 21, 12, 0, 0) do
      stale = create_agent(suffix: "stale", status: :online, last_heartbeat_at: 10.minutes.ago)
      live = create_agent(suffix: "live", status: :online, last_heartbeat_at: 1.minute.ago)

      assert_equal :never, never_seen.last_seen_state
      assert_equal :stale, stale.last_seen_state
      assert_equal :live, live.last_seen_state
    end
  end

  test "health_alerts includes stale heartbeat idle runner failed commands and pending commands" do
    travel_to Time.zone.local(2026, 4, 21, 12, 0, 0) do
      agent = create_agent(
        suffix: "alerts",
        status: :online,
        last_heartbeat_at: 10.minutes.ago,
        metadata: { "task_runner_active" => false }
      )

      alerts = agent.health_alerts(health_stats: { failed: 2, pending: 3 })

      assert_includes alerts, "Heartbeat is stale"
      assert_includes alerts, "Task runner is idle"
      assert_includes alerts, "2 command failures in 24h"
      assert_includes alerts, "3 commands pending"
    end
  end

  private

  def create_agent(suffix:, **attrs)
    Agent.create!(
      {
        user: @user,
        name: "Runtime #{suffix}",
        hostname: "runtime-#{suffix}.local",
        host_uid: "uid-runtime-#{suffix}",
        platform: "linux",
        version: "1.0.0",
        metadata: {},
        status: :offline
      }.merge(attrs)
    )
  end
end
