require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "shows apex workspace navigation and summary" do
    get home_url

    assert_response :success
    # New UI uses dashboard cards with greeting, stats, and sections instead of old nav
    assert_match(/Good (morning|afternoon|evening)/, response.body)
    assert_match "Agents online", response.body
    assert_match "In progress", response.body
    assert_match "Projects", response.body
  end

  test "shows actual online agent count instead of total agents" do
    Agent.create!(user: @user, name: "Online Agent", status: :online, last_heartbeat_at: 1.minute.ago)
    Agent.create!(user: @user, name: "Offline Agent", status: :offline, last_heartbeat_at: 1.minute.ago)
    Agent.create!(user: @user, name: "Stale Agent", status: :online, last_heartbeat_at: 10.minutes.ago)

    get home_url

    assert_response :success
    assert_match %r{>1/3<}, response.body
  end
end
