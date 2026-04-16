require "test_helper"
require "tempfile"

class Api::V1::TaskArtifactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear

    @user = users(:one)
    @api_token = api_tokens(:one)
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }

    @task = tasks(:one)
    @task.update!(assigned_agent: nil, claimed_by_agent: nil)

    @agent = Agent.create!(user: @user, name: "Artifact Agent")
    _agent_token, @agent_plaintext_token = AgentToken.issue!(agent: @agent, name: "Artifact Token")
    @agent_auth_header = { "Authorization" => "Bearer #{@agent_plaintext_token}" }
  end

  test "owner can upload artifact" do
    assert_difference "TaskArtifact.count", 1 do
      post api_v1_task_artifacts_url(@task),
           params: {
             file: uploaded_file("owner-report.txt", "owner artifact"),
             metadata: { source: "owner" }.to_json
           },
           headers: @auth_header,
           as: :multipart
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "owner-report.txt", body["filename"]
    assert_equal "text/plain", body["content_type"]
    assert_equal({ "source" => "owner" }, body["metadata"])
    assert @task.artifacts.last.file.attached?
  end

  test "assigned agent can upload artifact" do
    @task.update!(assigned_agent: @agent)

    post api_v1_task_artifacts_url(@task),
         params: { file: uploaded_file("agent-report.txt", "agent artifact") },
         headers: @agent_auth_header,
         as: :multipart

    assert_response :created
    assert_equal @task.id, TaskArtifact.last.task_id
  end

  test "claiming agent can upload artifact" do
    @task.update!(claimed_by_agent: @agent)

    post api_v1_task_artifacts_url(@task),
         params: { file: uploaded_file("claim-report.txt", "claimed artifact") },
         headers: @agent_auth_header,
         as: :multipart

    assert_response :created
  end

  test "other agent cannot upload artifact" do
    other_agent = Agent.create!(user: @user, name: "Other Agent")
    _token, other_plaintext = AgentToken.issue!(agent: other_agent, name: "Other Token")

    post api_v1_task_artifacts_url(@task),
         params: { file: uploaded_file("blocked.txt", "blocked") },
         headers: { "Authorization" => "Bearer #{other_plaintext}" },
         as: :multipart

    assert_response :forbidden
  end

  test "upload rejects invalid metadata json" do
    post api_v1_task_artifacts_url(@task),
         params: {
           file: uploaded_file("bad-metadata.txt", "bad metadata"),
           metadata: "not json"
         },
         headers: @auth_header,
         as: :multipart

    assert_response :unprocessable_entity
    assert_equal "Metadata must be valid JSON", response.parsed_body["error"]
  end

  test "list returns artifacts for owner" do
    artifact = create_artifact(filename: "list.txt", content: "list data")

    get api_v1_task_artifacts_url(@task), headers: @auth_header

    assert_response :success
    assert_equal [ artifact.id ], response.parsed_body.map { |entry| entry["id"] }
  end

  test "list returns artifacts for assigned agent" do
    @task.update!(assigned_agent: @agent)
    artifact = create_artifact(filename: "agent-list.txt", content: "agent list")

    get api_v1_task_artifacts_url(@task), headers: @agent_auth_header

    assert_response :success
    assert_equal artifact.id, response.parsed_body.first["id"]
  end

  test "list forbids unrelated agent" do
    create_artifact(filename: "forbidden-list.txt", content: "secret list")
    other_agent = Agent.create!(user: @user, name: "List Forbidden Agent")
    _token, other_plaintext = AgentToken.issue!(agent: other_agent, name: "List Forbidden Token")

    get api_v1_task_artifacts_url(@task), headers: { "Authorization" => "Bearer #{other_plaintext}" }

    assert_response :forbidden
  end

  test "download streams artifact for owner" do
    artifact = create_artifact(filename: "download.txt", content: "download body")

    get api_v1_task_artifact_url(@task, artifact), headers: @auth_header

    assert_response :success
    assert_equal "download body", response.body
    assert_equal "text/plain", response.media_type
    assert_match(/attachment; filename="download.txt"/, response.headers["Content-Disposition"])
  end

  test "download streams artifact for claiming agent" do
    @task.update!(claimed_by_agent: @agent)
    artifact = create_artifact(filename: "claimed-download.txt", content: "claimed body")

    get api_v1_task_artifact_url(@task, artifact), headers: @agent_auth_header

    assert_response :success
    assert_equal "claimed body", response.body
  end

  test "download forbids unrelated agent" do
    artifact = create_artifact(filename: "forbidden.txt", content: "secret")
    other_agent = Agent.create!(user: @user, name: "Forbidden Agent")
    _token, other_plaintext = AgentToken.issue!(agent: other_agent, name: "Forbidden Token")

    get api_v1_task_artifact_url(@task, artifact), headers: { "Authorization" => "Bearer #{other_plaintext}" }

    assert_response :forbidden
  end

  private

  def uploaded_file(filename, content, content_type = "text/plain")
    tempfile = Tempfile.new([ File.basename(filename, ".*"), File.extname(filename) ])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(
      tempfile.path,
      content_type,
      original_filename: filename
    )
  end

  def create_artifact(filename:, content:, content_type: "text/plain", metadata: {})
    artifact = @task.artifacts.new(
      filename: filename,
      content_type: content_type,
      size: content.bytesize,
      metadata: metadata
    )

    artifact.file.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )
    artifact.save!
    artifact.update_column(:storage_path, artifact.file.blob.key)
    artifact
  end
end
