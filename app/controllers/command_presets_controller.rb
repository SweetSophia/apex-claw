class CommandPresetsController < ApplicationController
  before_action :set_command_preset, only: [:show, :update, :destroy]

  def index
    @command_presets = current_user.command_presets.includes(:agent).recent
  end

  def show
  end

  def create
    @command_preset = current_user.command_presets.build(command_preset_params)
    if @command_preset.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("command_presets_list", partial: "command_presets/command_preset_card", locals: { command_preset: @command_preset }) }
        format.html { redirect_to command_presets_path, notice: "Command preset created" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("command_preset_form", partial: "command_presets/form", locals: { command_preset: @command_preset, agents: current_user.agents.active.order(:name) }), status: :unprocessable_entity }
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @command_preset.update(command_preset_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(@command_preset), partial: "command_presets/command_preset_card", locals: { command_preset: @command_preset }) }
        format.html { redirect_to command_preset_path(@command_preset), notice: "Command preset updated" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("command_preset_form", partial: "command_presets/form", locals: { command_preset: @command_preset, agents: current_user.agents.active.order(:name) }), status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @command_preset.destroy!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@command_preset)) }
      format.html { redirect_to command_presets_path, notice: "Command preset deleted" }
    end
  end

  private

  def set_command_preset
    @command_preset = current_user.command_presets.includes(:agent).find(params[:id])
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
end
