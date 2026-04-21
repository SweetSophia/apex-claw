class CreateHandoffTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :handoff_templates do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :name, null: false
      t.text :context_template, null: false
      t.references :agent, null: true, foreign_key: { on_delete: :nullify }, index: true
      t.boolean :auto_suggest, default: false, null: false
      t.timestamps
    end

    add_index :handoff_templates, [ :user_id, :name ], unique: true
  end
end
