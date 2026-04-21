class CreateWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_runs do |t|
      t.references :workflow, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.integer :status, null: false, default: 0
      t.integer :trigger_type, null: false, default: 0
      t.jsonb :result, null: false, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :workflow_runs, [:workflow_id, :status]
    add_index :workflow_runs, :created_at
  end
end
