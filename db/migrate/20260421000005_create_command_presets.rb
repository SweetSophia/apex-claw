class CreateCommandPresets < ActiveRecord::Migration[8.1]
  def change
    create_table :command_presets do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.references :agent, null: true, foreign_key: { on_delete: :nullify }, index: true
      t.string :name, null: false
      t.string :kind, null: false
      t.text :description
      t.jsonb :payload, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :command_presets, [:user_id, :name], unique: true
    add_index :command_presets, [:user_id, :active]
  end
end
