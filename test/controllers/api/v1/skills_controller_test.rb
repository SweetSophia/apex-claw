require "test_helper"

class Api::V1::SkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @user = users(:one)
    @user_token = api_tokens(:one).token
    @skill = Skill.create!(user: @user, name: "Test Skill", description: "A test skill", body: "Skill body content")
  end

  # ─── Index ──────────────────────────────────────────────────────────────

  test "index returns user's skills" do
    get "/api/v1/skills", headers: auth_header(@user_token)

    assert_response :success
    assert_equal 1, response.parsed_body["skills"].length
    assert_equal "Test Skill", response.parsed_body["skills"][0]["name"]
  end

  test "index excludes other user's skills" do
    other_user = users(:two)
    Skill.create!(user: other_user, name: "Other Skill")

    get "/api/v1/skills", headers: auth_header(@user_token)

    assert_response :success
    assert_equal 1, response.parsed_body["skills"].length
    assert_equal "Test Skill", response.parsed_body["skills"][0]["name"]
  end

  # ─── Show ────────────────────────────────────────────────────────────────

  test "show returns skill details" do
    get "/api/v1/skills/#{@skill.id}", headers: auth_header(@user_token)

    assert_response :success
    assert_equal "Test Skill", response.parsed_body["skill"]["name"]
    assert_equal "A test skill", response.parsed_body["skill"]["description"]
    assert_equal "Skill body content", response.parsed_body["skill"]["body"]
  end

  test "show 404 for other user's skill" do
    other_user = users(:two)
    other_skill = Skill.create!(user: other_user, name: "Other")

    get "/api/v1/skills/#{other_skill.id}", headers: auth_header(@user_token)

    assert_response :not_found
  end

  # ─── Create ─────────────────────────────────────────────────────────────

  test "create skill" do
    assert_difference "Skill.count", 1 do
      post "/api/v1/skills",
           headers: auth_header(@user_token),
           params: { skill: { name: "New Skill", description: "A new skill", body: "Body content" } }

      assert_response :created
      assert_equal "New Skill", response.parsed_body["skill"]["name"]
    end
  end

  test "create validates name presence" do
    post "/api/v1/skills",
         headers: auth_header(@user_token),
         params: { skill: { name: "" } }

    assert_response :unprocessable_entity
  end

  test "create rejects duplicate name for same user" do
    post "/api/v1/skills",
         headers: auth_header(@user_token),
         params: { skill: { name: "Test Skill" } }

    assert_response :unprocessable_entity
  end

  # ─── Update ─────────────────────────────────────────────────────────────

  test "update skill" do
    patch "/api/v1/skills/#{@skill.id}",
          headers: auth_header(@user_token),
          params: { skill: { name: "Updated Skill" } }

    assert_response :success
    assert_equal "Updated Skill", @skill.reload.name
  end

  test "update 404 for other user's skill" do
    other_user = users(:two)
    other_skill = Skill.create!(user: other_user, name: "Other")

    patch "/api/v1/skills/#{other_skill.id}",
          headers: auth_header(@user_token),
          params: { skill: { name: "Hacked" } }

    assert_response :not_found
  end

  # ─── Destroy ───────────────────────────────────────────────────────────

  test "destroy skill" do
    assert_difference "Skill.count", -1 do
      delete "/api/v1/skills/#{@skill.id}", headers: auth_header(@user_token)
      assert_response :no_content
    end
  end

  test "destroy 404 for other user's skill" do
    other_user = users(:two)
    other_skill = Skill.create!(user: other_user, name: "Other")

    delete "/api/v1/skills/#{other_skill.id}", headers: auth_header(@user_token)

    assert_response :not_found
  end

  private

  def auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
