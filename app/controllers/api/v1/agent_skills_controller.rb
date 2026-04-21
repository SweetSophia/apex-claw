module Api
  module V1
    class AgentSkillsController < BaseController
      before_action :set_agent
      before_action :require_owner_user!
      before_action :require_user_token!, only: [ :create, :destroy ]
      before_action :set_skill, only: [:destroy]

      def index
        skills = @agent.skills.recent
        render json: { skills: skills.map { |skill| skill_json(skill) } }
      end

      def create
        skill = current_user.skills.find(params[:skill_id])
        agent_skill = @agent.agent_skills.new(skill: skill)
        if agent_skill.save
          render json: { message: "Skill assigned", skill: skill_json(skill) }, status: :created
        else
          render json: { error: agent_skill.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @agent.agent_skills.find_by!(skill_id: params[:id]).destroy!
        head :no_content
      end

      private

      def set_agent
        @agent = Agent.find(params[:agent_id])
      end

      # Verifies the authenticated identity is allowed to access @agent.
      # Agent tokens may only manage skills for the agent they belong to.
      # User tokens may manage any agent belonging to the user.
      def require_owner_user!
        if current_agent_token.present?
          return if current_agent.id == @agent.id
        else
          return if @agent.user_id == current_user.id
        end
        render json: { error: "Forbidden" }, status: :forbidden
      end

      # Restricts write operations (create, destroy) to user-token auth only.
      def require_user_token!
        return if current_agent_token.nil?

        render json: { error: "Forbidden" }, status: :forbidden
      end

      def set_skill
        @skill = @agent.skills.find(params[:id])
      end

      def skill_json(skill)
        {
          id: skill.id,
          name: skill.name,
          description: skill.description,
          body: skill.body,
          shared: skill.shared,
          created_at: skill.created_at.iso8601,
          updated_at: skill.updated_at.iso8601
        }
      end
    end
  end
end
