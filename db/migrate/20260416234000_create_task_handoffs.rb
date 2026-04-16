class CreateTaskHandoffs < ActiveRecord::Migration[8.0]
  def change
    create_table :task_handoffs do |t|
      t.references :task, null: false, foreign_key: true
      t.references :from_agent, null: false, foreign_key: { to_table: :agents }
      t.references :to_agent, null: false, foreign_key: { to_table: :agents }
      t.text :context, null: false
      t.integer :status, default: 0, null: false
      t.datetime :responded_at

      t.timestamps
    end

    add_index :task_handoffs, :status
  end
end
