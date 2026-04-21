require "test_helper"

class Api::V1::AgentSkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @user = users(:one)
    @user_token = api_tokens(:one).token
    @agent = Agent.create!(user: @user, name: "Skill Agent", hostname: "skill.local", host_uid: "uid", platform: "linux")
    @skill = Skill.create!(user: @user, name: "Test Skill", body: "Skill body")
  end

  # ─── Index ──────────────────────────────────────────────────────────────

  test "index returns agent's skills" do
    @agent.agent_skills.create!(skill: @skill)

    get "/api/v1/agents/#{@agent.id}/skills", headers: auth_header(@user_token)

    assert_response :success
    assert_equal 1, response.parsed_body["skills"].length
    assert_equal "Test Skill", response.parsed_body["skills"][0]["name"]
  end

  test "index 403 for other user's agent" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other.local", host_uid: "uid2", platform: "linux")

    get "/api/v1/agents/#{other_agent.id}/skills", headers: auth_header(@user_token)

    assert_response :forbidden
  end

  # ─── Create ─────────────────────────────────────────────────────────────

  test "assign skill to agent" do
    assert_difference "AgentSkill.count", 1 do
      post "/api/v1/agents/#{@agent.id}/skills",
           headers: auth_header(@user_token),
           params: { skill_id: @skill.id }

      assert_response :created
      assert_equal "Skill assigned", response.parsed_body["message"]
    end
  end

  test "assign 403 for other user's agent" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other.local", host_uid: "uid2", platform: "linux")

    post "/api/v1/agents/#{other_agent.id}/skills",
         headers: auth_header(@user_token),
         params: { skill_id: @skill.id }

    assert_response :forbidden
  end

  test "assign 404 for skill not in user's workspace" do
    other_user = users(:two)
    other_skill = Skill.create!(user: other_user, name: "Other Skill")

    post "/api/v1/agents/#{@agent.id}/skills",
         headers: auth_header(@user_token),
         params: { skill_id: other_skill.id }

    assert_response :not_found
  end

  test "assign duplicate returns error" do
    @agent.agent_skills.create!(skill: @skill)

    post "/api/v1/agents/#{@agent.id}/skills",
         headers: auth_header(@user_token),
         params: { skill_id: @skill.id }

    assert_response :unprocessable_entity
  end

  # ─── Destroy ───────────────────────────────────────────────────────────

  test "remove skill from agent" do
    @agent.agent_skills.create!(skill: @skill)

    assert_difference "AgentSkill.count", -1 do
      delete "/api/v1/agents/#{@agent.id}/skills/#{@skill.id}", headers: auth_header(@user_token)
      assert_response :no_content
    end
  end

  test "remove 403 for other user's agent" do
    @agent.agent_skills.create!(skill: @skill)
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other.local", host_uid: "uid2", platform: "linux")

    delete "/api/v1/agents/#{other_agent.id}/skills/#{@skill.id}", headers: auth_header(@user_token)

    assert_response :forbidden
  end

  test "remove 404 for skill not assigned to agent" do
    delete "/api/v1/agents/#{@agent.id}/skills/#{@skill.id}", headers: auth_header(@user_token)

    assert_response :not_found
  end

  private

  def auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
