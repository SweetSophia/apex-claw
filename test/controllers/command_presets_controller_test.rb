require "test_helper"

class CommandPresetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @agent = Agent.create!(
      user: @user,
      name: "Preset Web Agent",
      hostname: "preset-web.local",
      host_uid: "preset-web-001",
      platform: "linux",
      version: "1.0.0"
    )
  end

  test "create preserves nested payload json" do
    nested_payload = {
      rollout: {
        strategy: "canary",
        steps: [
          { percent: 10 },
          { percent: 100 }
        ]
      },
      args: ["--verbose", { region: "iad" }]
    }

    assert_difference "CommandPreset.count", 1 do
      post command_presets_path, params: {
        command_preset: {
          name: "Nested Web Preset",
          kind: "config_reload",
          agent_id: @agent.id,
          payload: nested_payload
        }
      }
    end

    assert_redirected_to command_presets_path
    assert_equal nested_payload.deep_stringify_keys, CommandPreset.order(:created_at).last.payload
  end

  test "update preserves nested payload json" do
    preset = CommandPreset.create!(user: @user, agent: @agent, name: "Existing Preset", kind: "restart")
    nested_payload = {
      rollout: {
        strategy: "linear",
        steps: [
          { percent: 25 },
          { percent: 50 },
          { percent: 100 }
        ]
      },
      args: ["--graceful"]
    }

    patch command_preset_path(preset), params: { command_preset: { payload: nested_payload } }

    assert_redirected_to command_preset_path(preset)
    assert_equal nested_payload.deep_stringify_keys, preset.reload.payload
  end
end
