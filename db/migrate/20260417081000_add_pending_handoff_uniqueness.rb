class AddPendingHandoffUniqueness < ActiveRecord::Migration[8.0]
  def change
    add_index :task_handoffs,
              :task_id,
              unique: true,
              where: "status = 0",
              name: "index_task_handoffs_on_task_id_pending_unique"
  end
end
