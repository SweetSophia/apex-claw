class CreateWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_runs do |t|
      t.references :workflow, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.integer :status, null: false, default: 0
      t.jsonb :context, null: false, default: {}
      t.text :result_summary
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :workflow_runs, [:workflow_id, :created_at]
    add_index :workflow_runs, [:user_id, :created_at]
  end
end
