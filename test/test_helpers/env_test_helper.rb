require "monitor"

module EnvTestHelper
  def with_env(overrides)
    normalized_overrides = normalize_env_overrides(overrides)

    env_monitor.synchronize do
      previous = normalized_overrides.keys.to_h { |key| [ key, ENV[key] ] }

      normalized_overrides.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end

      yield
    ensure
      previous&.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
  end

  private

  def normalize_env_overrides(overrides)
    overrides.to_h do |key, value|
      normalized_key = key.to_s
      normalized_value = value.nil? ? nil : value.to_s
      [ normalized_key, normalized_value ]
    end
  end

  def env_monitor
    @env_monitor ||= Monitor.new
  end
end
