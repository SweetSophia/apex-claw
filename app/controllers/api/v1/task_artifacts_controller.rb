module Api
  module V1
    class TaskArtifactsController < BaseController
      MAX_ARTIFACT_SIZE = 25.megabytes

      before_action :set_task
      before_action :set_artifact, only: :show
      before_action :authorize_task_artifact_access!

      def index
        render json: @task.artifacts.order(created_at: :asc).map { |artifact| artifact_json(artifact) }
      end

      def create
        uploaded_file = params[:file]
        return render_missing_file unless uploaded_file
        return render_file_too_large(uploaded_file) if uploaded_file.size.to_i > MAX_ARTIFACT_SIZE

        metadata = parse_metadata(params[:metadata])
        return if performed?

        artifact = @task.artifacts.new(
          filename: uploaded_file.original_filename,
          content_type: uploaded_file.content_type,
          size: uploaded_file.size,
          metadata: metadata
        )
        artifact.file.attach(uploaded_file)

        if artifact.save
          artifact.update(storage_path: artifact.file.blob.key)
          render json: artifact_json(artifact), status: :created
        else
          render json: { error: artifact.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def show
        blob = @artifact.file.blob
        response.headers["Content-Type"] = blob.content_type || @artifact.content_type
        safe_name = @artifact.filename.gsub(/["\\]/, "")
        response.headers["Content-Disposition"] = %(attachment; filename="#{safe_name}")
        response.headers["Content-Length"] = blob.byte_size.to_s

        @artifact.file.download do |chunk|
          response.stream.write(chunk)
        end
      ensure
        response.stream.close
      end

      private

      def set_task
        @task = current_user.tasks.find(params[:task_id])
      end

      def set_artifact
        @artifact = @task.artifacts.find(params[:artifact_id])
      end

      def authorize_task_artifact_access!
        return if current_agent.nil?
        return if @task.assigned_agent_id == current_agent.id || @task.claimed_by_agent_id == current_agent.id

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def parse_metadata(raw_metadata)
        return {} if raw_metadata.blank?

        parsed = JSON.parse(raw_metadata)
        unless parsed.is_a?(Hash)
          render json: { error: "Metadata must be a JSON object" }, status: :unprocessable_entity
          return
        end

        parsed
      rescue JSON::ParserError
        render json: { error: "Metadata must be valid JSON" }, status: :unprocessable_entity
        nil
      end

      def render_missing_file
        render json: { error: "File is required" }, status: :unprocessable_entity
      end

      def render_file_too_large(uploaded_file)
        render json: { error: "File exceeds max size of #{MAX_ARTIFACT_SIZE} bytes", size: uploaded_file.size.to_i }, status: :unprocessable_entity
      end

      def artifact_json(artifact)
        {
          id: artifact.id,
          filename: artifact.filename,
          content_type: artifact.content_type,
          size: artifact.size,
          metadata: artifact.metadata || {},
          created_at: artifact.created_at.iso8601,
          updated_at: artifact.updated_at.iso8601
        }
      end
    end
  end
end
