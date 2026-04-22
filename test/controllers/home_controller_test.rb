require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "shows apex workspace navigation and summary" do
    get home_url

    assert_response :success
    assert_match "Apex workspace", response.body
    assert_match "Skills", response.body
    assert_match "Workflows", response.body
    assert_match "Handoffs", response.body
    assert_match "Routing", response.body
    assert_match "Presets", response.body
  end
end
