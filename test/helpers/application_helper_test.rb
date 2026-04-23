require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = boards(:one)
    @task = tasks(:one)
    @task.update!(name: "Helper task", status: :up_next)
  end

  test "command bar new task action carries board id and deep link for current board" do
    items = helper_context.command_bar_search_items(@user, current_board: @board, tasks_scope: @board.tasks)
    new_task = items.find { |item| item[:actionType] == "new_task" }

    assert_not_nil new_task
    assert_equal @board.id, new_task[:boardId]
    assert_equal helper_context.board_path(@board, new_task: 1), new_task[:href]
  end

  test "command bar falls back to the first non-onboarding board when no current board is present" do
    user = User.create!(email_address: "fallback@example.com", password: "password123")
    onboarding_board = user.boards.first
    project_board = user.boards.create!(name: "Real Project", position: onboarding_board.position + 1)

    items = helper_context.command_bar_search_items(user)
    new_task = items.find { |item| item[:actionType] == "new_task" }

    assert_not_nil new_task
    assert_equal project_board.id, new_task[:boardId]
    assert_equal helper_context.board_path(project_board, new_task: 1), new_task[:href]
    assert_equal "Create in Real Project", new_task[:subtitle]
  end

  test "marketing base url uses request when env overrides are missing" do
    request = Struct.new(:protocol, :host_with_port).new("https://", "example.test:4000")

    with_env("APP_HOST" => nil, "APP_PROTOCOL" => nil) do
      assert_equal "https://example.test:4000", helper_context.marketing_base_url(request: request)
    end
  end

  test "marketing base url prefers env overrides" do
    request = Struct.new(:protocol, :host_with_port).new("http://", "ignored.test:3000")

    with_env("APP_HOST" => "apex.example", "APP_PROTOCOL" => "https") do
      assert_equal "https://apex.example", helper_context.marketing_base_url(request: request)
    end
  end

  test "marketing base url strips protocol suffix from env override" do
    request = Struct.new(:protocol, :host_with_port).new("http://", "ignored.test:3000")

    with_env("APP_HOST" => "apex.example", "APP_PROTOCOL" => "https://") do
      assert_equal "https://apex.example", helper_context.marketing_base_url(request: request)
    end
  end

  test "marketing base url brackets ipv6 app host override" do
    request = Struct.new(:protocol, :host_with_port).new("http://", "ignored.test:3000")

    with_env("APP_HOST" => "::1", "APP_PROTOCOL" => "https") do
      assert_equal "https://[::1]", helper_context.marketing_base_url(request: request)
    end
  end

  test "marketing base url does not double-bracket already-bracketed ipv6 app host" do
    request = Struct.new(:protocol, :host_with_port).new("http://", "ignored.test:3000")

    with_env("APP_HOST" => "[::1]", "APP_PROTOCOL" => "https") do
      assert_equal "https://[::1]", helper_context.marketing_base_url(request: request)
    end
  end

  test "marketing host brackets ipv6 app host override" do
    request = Struct.new(:protocol, :host_with_port).new("http://", "ignored.test:3000")

    with_env("APP_HOST" => "::1", "APP_PROTOCOL" => "https") do
      assert_equal "[::1]", helper_context.marketing_host(request: request)
    end
  end

  test "marketing base url uses configured allowed host in production when app host is unset" do
    request = Struct.new(:protocol, :host_with_port).new("https://", "attacker.test")

    with_env("APP_HOST" => nil, "APP_PROTOCOL" => nil, "APP_ALLOWED_HOSTS" => "public.apex.test,127.0.0.1") do
      with_rails_env("production") do
        assert_equal "https://public.apex.test", helper_context.marketing_base_url(request: request)
      end
    end
  end

  test "marketing base url ignores request protocol in production when app protocol is unset" do
    request = Struct.new(:protocol, :host_with_port).new("http://", "public.apex.test")

    with_env("APP_HOST" => "public.apex.test", "APP_PROTOCOL" => nil, "APP_ALLOWED_HOSTS" => nil) do
      with_rails_env("production") do
        assert_equal "https://public.apex.test", helper_context.marketing_base_url(request: request)
      end
    end
  end

  test "marketing base url falls back to local default in production when no host config is present" do
    request = Struct.new(:protocol, :host_with_port).new("https://", "attacker.test")

    with_env("APP_HOST" => nil, "APP_PROTOCOL" => nil, "APP_ALLOWED_HOSTS" => nil) do
      with_rails_env("production") do
        assert_equal "https://apexclaw.local", helper_context.marketing_base_url(request: request)
      end
    end
  end

  test "marketing base url skips wildcard entries in APP_ALLOWED_HOSTS and uses the first concrete host" do
    request = Struct.new(:protocol, :host_with_port).new("https://", "attacker.test")

    with_env("APP_HOST" => nil, "APP_PROTOCOL" => nil, "APP_ALLOWED_HOSTS" => ".apex.test,public.apex.test") do
      with_rails_env("production") do
        assert_equal "https://public.apex.test", helper_context.marketing_base_url(request: request)
      end
    end
  end

  test "marketing base url brackets ipv6 allowed host in production" do
    request = Struct.new(:protocol, :host_with_port).new("https://", "attacker.test")

    with_env("APP_HOST" => nil, "APP_PROTOCOL" => nil, "APP_ALLOWED_HOSTS" => "::1,127.0.0.1") do
      with_rails_env("production") do
        assert_equal "https://[::1]", helper_context.marketing_base_url(request: request)
      end
    end
  end

  test "marketing base url falls back to default when request is nil" do
    with_env("APP_HOST" => nil, "APP_PROTOCOL" => nil) do
      assert_equal "https://apexclaw.local", helper_context.marketing_base_url(request: nil)
    end
  end

  test "workspace nav includes apex control plane destinations" do
    items = helper_context.workspace_nav_items(@user)

    assert_equal ["Home", "Agents", "Skills", "Workflows", "Handoffs", "Routing", "Presets", "Settings"], items.map { |item| item[:title] }
  end

  test "command bar exposes workspace nav pages" do
    items = helper_context.command_bar_search_items(@user)

    assert_includes items.map { |item| item[:href] }, helper_context.skills_path
    assert_includes items.map { |item| item[:href] }, helper_context.workflows_path
    assert_includes items.map { |item| item[:href] }, helper_context.handoff_templates_path
    assert_includes items.map { |item| item[:href] }, helper_context.routing_rules_path
    assert_includes items.map { |item| item[:href] }, helper_context.command_presets_path
  end

  test "workspace nav keeps explicit search keywords for command bar items" do
    items = helper_context.command_bar_search_items(@user)
    settings_item = items.find { |item| item[:kind] == "nav" && item[:href] == helper_context.settings_path }

    assert_not_nil settings_item
    assert_includes settings_item[:keywords], "api"
    assert_includes settings_item[:keywords], "token"
  end

  test "nav item active check requires exact match or path boundary" do
    agents_item = helper_context.workspace_nav_items(@user).find { |item| item[:href] == helper_context.agents_path }

    assert helper_context.nav_item_active?(agents_item, "/agents")
    assert helper_context.nav_item_active?(agents_item, "/agents/123")
    assert_not helper_context.nav_item_active?(agents_item, "/agents-logs")
  end

  test "board onboarding state uses persisted marker instead of board name" do
    board = Board.new(name: Board::ONBOARDING_NAME, onboarding_seeded: false)

    assert_not board.onboarding?

    board.onboarding_seeded = true
    assert board.onboarding?
  end

  private

  def helper_context
    @helper_context ||= Class.new do
      include ApplicationHelper
      include Rails.application.routes.url_helpers

      def default_url_options
        {}
      end
    end.new
  end
end
