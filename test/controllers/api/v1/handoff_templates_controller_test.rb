require "test_helper"

class Api::V1::HandoffTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @user = users(:one)
    @user_token = api_tokens(:one).token
    @agent = Agent.create!(user: @user, name: "API Template Agent", hostname: "api-template.local", host_uid: "uid-api-template", platform: "linux", status: :online)
    @template = HandoffTemplate.create!(user: @user, agent: @agent, name: "Test Template", context_template: "Test context")
  end

  test "index returns templates for current user" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other.local", host_uid: "uid-other", platform: "linux", status: :online)
    HandoffTemplate.create!(user: other_user, agent: other_agent, name: "Other Template", context_template: "Other context")

    get "/api/v1/handoff_templates", headers: auth_header(@user_token)

    assert_response :success
    assert_equal 1, response.parsed_body["templates"].length
    assert_equal "Test Template", response.parsed_body["templates"][0]["name"]
  end

  test "show returns single template" do
    get "/api/v1/handoff_templates/#{@template.id}", headers: auth_header(@user_token)

    assert_response :success
    assert_equal "Test Template", response.parsed_body["template"]["name"]
    assert_equal "Test context", response.parsed_body["template"]["context_template"]
  end

  test "create creates template" do
    assert_difference "HandoffTemplate.count", 1 do
      post "/api/v1/handoff_templates",
           headers: auth_header(@user_token),
           params: { handoff_template: { name: "New Template", context_template: "New context", agent_id: @agent.id, auto_suggest: true } }

      assert_response :created
      assert_equal "New Template", response.parsed_body["template"]["name"]
    end
  end

  test "create returns errors for invalid params" do
    post "/api/v1/handoff_templates",
         headers: auth_header(@user_token),
         params: { handoff_template: { name: "", context_template: "" } }

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"], "Name can't be blank"
  end

  test "update updates template" do
    patch "/api/v1/handoff_templates/#{@template.id}",
          headers: auth_header(@user_token),
          params: { handoff_template: { name: "Updated Template", auto_suggest: true } }

    assert_response :success
    assert_equal "Updated Template", @template.reload.name
    assert_equal true, @template.auto_suggest
  end

  test "destroy deletes template" do
    assert_difference "HandoffTemplate.count", -1 do
      delete "/api/v1/handoff_templates/#{@template.id}", headers: auth_header(@user_token)

      assert_response :no_content
    end
  end

  test "cannot access other user's templates" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other-show.local", host_uid: "uid-other-show", platform: "linux", status: :online)
    other_template = HandoffTemplate.create!(user: other_user, agent: other_agent, name: "Secret Template", context_template: "Secret context")

    get "/api/v1/handoff_templates/#{other_template.id}", headers: auth_header(@user_token)

    assert_response :not_found
  end

  private

  def auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
