class AddOutputToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :output, :text
  end
end
