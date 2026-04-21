class CreateAgentSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_skills do |t|
      t.references :agent, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :skill, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.timestamps
    end

    add_index :agent_skills, [:agent_id, :skill_id], unique: true, name: "index_agent_skills_on_agent_and_skill"
  end
end