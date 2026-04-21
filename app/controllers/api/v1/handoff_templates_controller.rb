module Api
  module V1
    class HandoffTemplatesController < BaseController
      before_action :set_template, only: [ :show, :update, :destroy ]
      before_action :require_user_token!, only: [ :create, :update, :destroy ]

      def index
        templates = current_user.handoff_templates.includes(:agent).recent
        render json: { templates: templates.map { |t| template_json(t) } }
      end

      def show
        render json: { template: template_json(@template) }
      end

      def create
        @template = current_user.handoff_templates.build(template_params)
        if @template.save
          render json: { template: template_json(@template) }, status: :created
        else
          render json: { error: @template.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        if @template.update(template_params)
          render json: { template: template_json(@template) }
        else
          render json: { error: @template.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @template.destroy!
        head :no_content
      end

      private

      def set_template
        @template = current_user.handoff_templates.includes(:agent).find(params[:id])
      end

      def template_params
        params.require(:handoff_template).permit(:name, :context_template, :agent_id, :auto_suggest)
      end

      def require_user_token!
        return unless current_agent_token
        render json: { error: "Forbidden" }, status: :forbidden
      end

      def template_json(template)
        {
          id: template.id,
          name: template.name,
          context_template: template.context_template,
          agent_id: template.agent_id,
          agent_name: template.agent&.name,
          auto_suggest: template.auto_suggest,
          created_at: template.created_at.iso8601,
          updated_at: template.updated_at.iso8601
        }
      end
    end
  end
end
