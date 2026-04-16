class AddRotationFieldsToAgentTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :agent_tokens, :expires_at, :datetime
    add_column :agent_tokens, :revoked_at, :datetime
    add_column :agent_tokens, :last_rotated_at, :datetime

    add_index :agent_tokens, [ :agent_id, :revoked_at ]
  end
end
