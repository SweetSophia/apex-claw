class AddCommandPresetToAgentCommands < ActiveRecord::Migration[8.1]
  def change
    add_reference :agent_commands, :command_preset, null: true, foreign_key: { on_delete: :nullify }, index: true
  end
end
