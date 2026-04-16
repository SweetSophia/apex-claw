require "test_helper"
require "tempfile"

class TaskArtifactTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @board = @user.boards.first || @user.boards.create!(name: "Test Board", icon: "📋", color: "gray")
    @task = Task.create!(user: @user, board: @board, name: "Artifact Task")
  end

  test "belongs to task" do
    artifact = build_artifact
    assert_equal @task, artifact.task
  end

  test "requires filename" do
    artifact = build_artifact(filename: nil)
    assert_not artifact.valid?
    assert_includes artifact.errors[:filename], "can't be blank"
  end

  test "requires content type" do
    artifact = build_artifact(content_type: nil)
    assert_not artifact.valid?
    assert_includes artifact.errors[:content_type], "can't be blank"
  end

  test "requires positive size" do
    artifact = build_artifact(size: 0)
    assert_not artifact.valid?
    assert_includes artifact.errors[:size], "must be greater than 0"
  end

  test "requires attached file" do
    artifact = TaskArtifact.new(task: @task, filename: "report.txt", content_type: "text/plain", size: 12)
    assert_not artifact.valid?
    assert_includes artifact.errors[:file], "must be attached"
  end

  test "task has many artifacts" do
    build_artifact.save!
    build_artifact(filename: "second.txt").save!

    assert_equal 2, @task.artifacts.count
  end

  private

  def build_artifact(filename: "report.txt", content_type: "text/plain", size: 12)
    artifact = TaskArtifact.new(
      task: @task,
      filename: filename,
      content_type: content_type,
      size: size,
      metadata: { "kind" => "report" }
    )

    attached_filename = filename || "report.txt"
    tempfile = Tempfile.new([ File.basename(attached_filename, ".*"), File.extname(attached_filename) ])
    tempfile.binmode
    tempfile.write("artifact data")
    tempfile.rewind

    artifact.file.attach(
      io: tempfile,
      filename: attached_filename,
      content_type: content_type || "text/plain"
    )

    artifact
  end
end
