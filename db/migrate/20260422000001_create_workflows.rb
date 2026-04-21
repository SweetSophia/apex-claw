class CreateWorkflows < ActiveRecord::Migration[8.1]
  def change
    create_table :workflows do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :agent, null: true, foreign_key: { on_delete: :nullify }, index: true
      t.string :name, null: false
      t.text :description
      t.integer :trigger_type, null: false, default: 0
      t.jsonb :trigger_config, null: false, default: {}
      t.integer :execution_mode, null: false, default: 0
      t.jsonb :task_template, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.datetime :last_run_at
      t.timestamps
    end

    add_index :workflows, [:user_id, :status]
    add_index :workflows, :trigger_type
  end
end
