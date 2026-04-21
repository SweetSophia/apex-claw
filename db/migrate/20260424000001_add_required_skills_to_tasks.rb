class AddRequiredSkillsToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :required_skills, :string, default: [], array: true
    add_index :tasks, :required_skills
    add_column :tasks, :escalation_config, :jsonb, default: {}
  end
end
