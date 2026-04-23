require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials logs in user" do
    post session_path, params: { email_address: @user.email_address, password: "password123" }

    assert_redirected_to boards_path
    assert cookies[:session_id]
  end

  test "create marks session cookie secure when APP_PROTOCOL includes scheme suffix" do
    previous_https = https?

    with_env("APP_PROTOCOL" => "https://", "APP_FORCE_SSL" => nil) do
      https!

      post session_path, params: { email_address: @user.email_address, password: "password123" }

      assert_redirected_to boards_path

      session_cookie = cookies.instance_variable_get(:@cookies).find { |cookie| cookie.name == "session_id" }

      assert session_cookie, "expected session_id cookie in cookie jar"
      assert session_cookie.secure?
    end
  ensure
    https!(previous_https)
  end

  test "create with invalid password shows error" do
    post session_path, params: { email_address: @user.email_address, password: "wrongpassword" }

    assert_redirected_to new_session_path
    assert_equal "Invalid email or password.", flash[:alert]
  end

  test "create with non-existent email shows error" do
    post session_path, params: { email_address: "nonexistent@example.com", password: "password123" }

    assert_redirected_to new_session_path
    assert_equal "No account found with that email. Please sign up first.", flash[:alert]
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
