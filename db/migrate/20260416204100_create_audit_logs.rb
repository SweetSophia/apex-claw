class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.string :actor_type
      t.bigint :actor_id
      t.string :action, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id, null: false
      t.jsonb :audited_changes, null: false, default: {}
      t.string :ip_address
      t.string :user_agent
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, [ :actor_type, :actor_id ]
    add_index :audit_logs, [ :resource_type, :resource_id ]
    add_index :audit_logs, :created_at
  end
end
