require "test_helper"

class Api::V1::WorkflowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @user = users(:one)
    @user_token = api_tokens(:one).token
    @agent = Agent.create!(user: @user, name: "API WF Agent", hostname: "api-wf.local", host_uid: "uid-api-wf", platform: "linux", status: :online)
    @workflow = Workflow.create!(user: @user, agent: @agent, name: "Test Workflow", description: "A test")
  end

  # ─── Index ──────────────────────────────────────────────────────────────

  test "index returns user's workflows" do
    get "/api/v1/workflows", headers: auth_header(@user_token)
    assert_response :success
    assert_equal 1, response.parsed_body["workflows"].length
  end

  test "index excludes other user's workflows" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "Other Agent", hostname: "other.local", host_uid: "uid-o", platform: "linux")
    Workflow.create!(user: other_user, agent: other_agent, name: "Other WF")

    get "/api/v1/workflows", headers: auth_header(@user_token)
    assert_response :success
    assert_equal 1, response.parsed_body["workflows"].length
  end

  # ─── Show ────────────────────────────────────────────────────────────────

  test "show returns workflow with runs" do
    get "/api/v1/workflows/#{@workflow.id}", headers: auth_header(@user_token)
    assert_response :success
    assert_equal "Test Workflow", response.parsed_body["workflow"]["name"]
    assert_equal [], response.parsed_body["workflow"]["runs"]
  end

  test "show 404 for other user's workflow" do
    other_user = users(:two)
    other_agent = Agent.create!(user: other_user, name: "O", hostname: "o.local", host_uid: "uo", platform: "linux")
    other_wf = Workflow.create!(user: other_user, agent: other_agent, name: "Secret")

    get "/api/v1/workflows/#{other_wf.id}", headers: auth_header(@user_token)
    assert_response :not_found
  end

  # ─── Create ─────────────────────────────────────────────────────────────

  test "create workflow" do
    assert_difference "Workflow.count", 1 do
      post "/api/v1/workflows",
           headers: auth_header(@user_token),
           params: { workflow: { name: "New WF", agent_id: @agent.id, trigger_type: :manual, execution_mode: :create_task } }
      assert_response :created
    end
  end

  test "create validates name" do
    post "/api/v1/workflows",
         headers: auth_header(@user_token),
         params: { workflow: { name: "", agent_id: @agent.id } }
    assert_response :unprocessable_entity
  end

  # ─── Update ─────────────────────────────────────────────────────────────

  test "update workflow" do
    patch "/api/v1/workflows/#{@workflow.id}",
          headers: auth_header(@user_token),
          params: { workflow: { name: "Updated WF" } }
    assert_response :success
    assert_equal "Updated WF", @workflow.reload.name
  end

  # ─── Destroy ───────────────────────────────────────────────────────────

  test "destroy workflow" do
    assert_difference "Workflow.count", -1 do
      delete "/api/v1/workflows/#{@workflow.id}", headers: auth_header(@user_token)
      assert_response :no_content
    end
  end

  # ─── Run ────────────────────────────────────────────────────────────────

  test "run triggers a workflow" do
    assert_enqueued_with(job: WorkflowRunJob) do
      post "/api/v1/workflows/#{@workflow.id}/run", headers: auth_header(@user_token)
      assert_response :accepted
      assert response.parsed_body["run"].present?
    end
  end

  test "run returns 422 for non-runnable workflow" do
    @workflow.update!(status: :paused)
    post "/api/v1/workflows/#{@workflow.id}/run", headers: auth_header(@user_token)
    assert_response :unprocessable_entity
  end

  private

  def auth_header(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
