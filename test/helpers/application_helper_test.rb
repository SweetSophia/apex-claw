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

    previous_host = ENV["APP_HOST"]
    previous_protocol = ENV["APP_PROTOCOL"]
    ENV.delete("APP_HOST")
    ENV.delete("APP_PROTOCOL")

    assert_equal "https://example.test:4000", helper_context.marketing_base_url(request: request)
  ensure
    ENV["APP_HOST"] = previous_host
    ENV["APP_PROTOCOL"] = previous_protocol
  end

  test "marketing base url prefers env overrides" do
    request = Struct.new(:protocol, :host_with_port).new("http://", "ignored.test:3000")

    previous_host = ENV["APP_HOST"]
    previous_protocol = ENV["APP_PROTOCOL"]
    ENV["APP_HOST"] = "apex.example"
    ENV["APP_PROTOCOL"] = "https"

    assert_equal "https://apex.example", helper_context.marketing_base_url(request: request)
  ensure
    ENV["APP_HOST"] = previous_host
    ENV["APP_PROTOCOL"] = previous_protocol
  end

  test "marketing base url falls back to default when request is nil" do
    previous_host = ENV["APP_HOST"]
    previous_protocol = ENV["APP_PROTOCOL"]
    ENV.delete("APP_HOST")
    ENV.delete("APP_PROTOCOL")

    assert_equal "https://apexclaw.local", helper_context.marketing_base_url(request: nil)
  ensure
    ENV["APP_HOST"] = previous_host
    ENV["APP_PROTOCOL"] = previous_protocol
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
