class AddUserIdToWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    # user_id column was added to support belongs_to :user association in WorkflowRun model
    # The column already exists in the schema (added manually); this migration documents it
    add_reference :workflow_runs, :user, null: false, foreign_key: true unless column_exists?(:workflow_runs, :user_id)
  end
end
