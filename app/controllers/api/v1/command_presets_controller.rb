module Api
  module V1
    class CommandPresetsController < BaseController
      before_action :set_command_preset, only: [:show, :update, :destroy]
      before_action :require_user_token!, only: [:create, :update, :destroy]

      def index
        presets = current_user.command_presets.includes(:agent).recent
        presets = presets.where(agent_id: [nil, params[:agent_id]]) if params[:agent_id].present?

        render json: { command_presets: presets.map { |preset| command_preset_json(preset) } }
      end

      def show
        render json: { command_preset: command_preset_json(@command_preset) }
      end

      def create
        @command_preset = current_user.command_presets.build(command_preset_params)
        if @command_preset.save
          render json: { command_preset: command_preset_json(@command_preset) }, status: :created
        else
          render json: { error: @command_preset.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def update
        if @command_preset.update(command_preset_params)
          render json: { command_preset: command_preset_json(@command_preset) }
        else
          render json: { error: @command_preset.errors.full_messages.join(", ") }, status: :unprocessable_entity
        end
      end

      def destroy
        @command_preset.destroy!
        head :no_content
      end

      private

      def set_command_preset
        @command_preset = current_user.command_presets.includes(:agent).find(params[:id])
      end

      def require_user_token!
        return unless current_agent_token
        render json: { error: "Forbidden" }, status: :forbidden
      end

      def command_preset_params
        attrs = params.require(:command_preset).permit(:name, :description, :kind, :agent_id, :active)
        payload = params[:command_preset][:payload] if params[:command_preset].respond_to?(:key?) && params[:command_preset].key?(:payload)
        attrs[:payload] = normalize_payload(payload) unless payload.nil?
        attrs
      end

      def normalize_payload(value)
        case value
        when ActionController::Parameters
          value.to_unsafe_h.transform_values { |nested| normalize_payload(nested) }
        when Hash
          value.transform_values { |nested| normalize_payload(nested) }
        when Array
          value.map { |nested| normalize_payload(nested) }
        when String
          coerce_scalar(value)
        else
          value
        end
      end

      def coerce_scalar(value)
        return true if value == "true"
        return false if value == "false"
        return nil if value == "null"
        return value.to_i if value.match?(/\A-?\d+\z/)
        return value.to_f if value.match?(/\A-?\d+\.\d+\z/)

        value
      end

      def command_preset_json(preset)
        {
          id: preset.id,
          name: preset.name,
          description: preset.description,
          kind: preset.kind,
          payload: preset.payload,
          active: preset.active,
          agent_id: preset.agent_id,
          agent_name: preset.agent&.name,
          created_at: preset.created_at.iso8601,
          updated_at: preset.updated_at.iso8601
        }
      end
    end
  end
end
