require "test_helper"

class Api::V1::TaskHandoffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear

    @user = users(:one)
    @task = tasks(:one)

    @from_agent = Agent.create!(user: @user, name: "From Agent")
    @from_token, @from_plaintext = AgentToken.issue!(agent: @from_agent, name: "Primary")
    @from_auth = { "Authorization" => "Bearer #{@from_plaintext}" }

    @to_agent = Agent.create!(user: @user, name: "To Agent")
    @to_token, @to_plaintext = AgentToken.issue!(agent: @to_agent, name: "Primary")
    @to_auth = { "Authorization" => "Bearer #{@to_plaintext}" }

    # Assign task to from_agent so they can handoff
    @task.update!(assigned_agent: @from_agent, claimed_by_agent: @from_agent)
  end

  # --- Create (handoff) ---

  test "initiate handoff as assigned agent" do
    assert_difference "TaskHandoff.count", 1 do
      post handoff_api_v1_task_url(@task),
        params: { to_agent_id: @to_agent.id, context: "Please take over" },
        headers: @from_auth
    end
    assert_response :created
    body = response.parsed_body
    assert_equal "pending", body["status"]
    assert_equal "Please take over", body["context"]
  end

  test "initiate handoff as claiming agent" do
    @task.update!(assigned_agent: nil, claimed_by_agent: @from_agent)
    post handoff_api_v1_task_url(@task),
      params: { to_agent_id: @to_agent.id, context: "Yours now" },
      headers: @from_auth
    assert_response :created
  end

  test "reject handoff from non-assigned agent" do
    post handoff_api_v1_task_url(@task),
      params: { to_agent_id: @to_agent.id, context: "Nope" },
      headers: @to_auth
    assert_response :forbidden
  end

  test "auto_accept handoff" do
    post handoff_api_v1_task_url(@task),
      params: { to_agent_id: @to_agent.id, context: "Auto", auto_accept: true },
      headers: @from_auth
    assert_response :created
    body = response.parsed_body
    assert_equal "accepted", body["status"]
    assert_equal @to_agent.id, @task.reload.assigned_agent_id
  end

  test "handoff requires context" do
    post handoff_api_v1_task_url(@task),
      params: { to_agent_id: @to_agent.id },
      headers: @from_auth
    assert_response :unprocessable_entity
  end

  # --- Accept ---

  test "target agent accepts handoff" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "Take this")

    patch accept_api_v1_task_handoff_url(handoff), headers: @to_auth
    assert_response :success
    assert_equal "accepted", handoff.reload.status
    assert_equal @to_agent.id, @task.reload.assigned_agent_id
    assert_equal @to_agent.id, @task.claimed_by_agent_id
  end

  test "non-target agent cannot accept" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "Take this")

    patch accept_api_v1_task_handoff_url(handoff), headers: @from_auth
    assert_response :forbidden
  end

  test "cannot accept non-pending handoff" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "Take this", status: :rejected)

    patch accept_api_v1_task_handoff_url(handoff), headers: @to_auth
    assert_response :unprocessable_entity
  end

  # --- Reject ---

  test "target agent rejects handoff" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "Take this")

    patch reject_api_v1_task_handoff_url(handoff), headers: @to_auth
    assert_response :success
    assert_equal "rejected", handoff.reload.status
  end

  test "non-target agent cannot reject" do
    handoff = TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "Take this")

    patch reject_api_v1_task_handoff_url(handoff), headers: @from_auth
    assert_response :forbidden
  end

  # --- Index ---

  test "list handoffs for agent" do
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    TaskHandoff.create!(task: @task, from_agent: @to_agent, to_agent: @from_agent, context: "B")

    get api_v1_task_handoffs_url, headers: @from_auth
    assert_response :success
    body = response.parsed_body
    assert_equal 2, body.length
  end

  test "filter handoffs by status" do
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "A")
    TaskHandoff.create!(task: @task, from_agent: @from_agent, to_agent: @to_agent, context: "B", status: :accepted)

    get api_v1_task_handoffs_url, params: { status: "pending" }, headers: @from_auth
    assert_response :success
    assert_equal 1, response.parsed_body.length
  end

  test "unauthenticated request is rejected" do
    get api_v1_task_handoffs_url
    assert_response :unauthorized
  end
end
