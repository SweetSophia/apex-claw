require "monitor"

module EnvTestHelper
  ENV_MONITOR = Monitor.new

  def with_env(overrides)
    ENV_MONITOR.synchronize do
      previous = overrides.keys.to_h { |key| [ key, ENV[key] ] }

      overrides.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end

      yield
    ensure
      previous.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
  end
end
