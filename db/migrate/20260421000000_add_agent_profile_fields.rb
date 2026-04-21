class AddAgentProfileFields < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :instructions, :text
    add_column :agents, :custom_env, :jsonb, null: false, default: {}
    add_column :agents, :custom_args, :jsonb, null: false, default: []
    add_column :agents, :model, :string
    add_column :agents, :max_concurrent_tasks, :integer, null: false, default: 1
    add_column :agents, :archived_at, :datetime
    add_column :agents, :archived_by_id, :bigint

    add_index :agents, :archived_at
    add_index :agents, [:user_id, :archived_at]
    add_foreign_key :agents, :users, column: :archived_by_id, on_delete: :nullify
  end
end
