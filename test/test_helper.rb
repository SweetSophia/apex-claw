ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/env_test_helper"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel using processes so temporary ENV overrides stay
    # isolated to a worker and are restored via EnvTestHelper.
    parallelize(workers: :number_of_processors, with: :processes)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include EnvTestHelper

    # Add more helper methods to be used by all tests here...
  end
end
