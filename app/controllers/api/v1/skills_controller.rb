module Api
  module V1
    class SkillsController < BaseController
      before_action :set_skill, only: [ :show, :update, :destroy ]
      before_action :require_user_token!, only: [ :create, :update, :destroy ]

      def index
        skills = current_user.skills.recent.includes(:agent_skills)
        render json: { skills: skills.map { |skill| skill_json(skill) } }
      end

      def show
        render json: { skill: skill_json(@skill) }
      end

      def create
        @skill = current_user.skills.build(skill_params)
        if @skill.save
          render json: { skill: skill_json(@skill) }, status: :created
        else
          render json: { error: @skill.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        if @skill.update(skill_params)
          render json: { skill: skill_json(@skill) }
        else
          render json: { error: @skill.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @skill.destroy!
        head :no_content
      end

      private

      def set_skill
        @skill = current_user.skills.find(params[:id])
      end

      def require_user_token!
        return if current_agent_token.nil?

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def skill_params
        params.require(:skill).permit(:name, :description, :body, :shared)
      end

      def skill_json(skill)
        {
          id: skill.id,
          name: skill.name,
          description: skill.description,
          body: skill.body,
          shared: skill.shared,
          agent_ids: skill.agent_ids,
          created_at: skill.created_at.iso8601,
          updated_at: skill.updated_at.iso8601
        }
      end
    end
  end
end
