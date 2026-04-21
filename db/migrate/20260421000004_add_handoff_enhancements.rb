class AddHandoffEnhancements < ActiveRecord::Migration[8.1]
  def change
    add_reference :task_handoffs, :handoff_template, null: true, foreign_key: { on_delete: :nullify }, index: true
    add_column :task_handoffs, :escalation, :boolean, default: false, null: false
    add_column :task_handoffs, :reason, :string
  end
end
