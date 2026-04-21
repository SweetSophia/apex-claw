class CreateRoutingRules < ActiveRecord::Migration[8.1]
  def change
    create_table :routing_rules do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :name, null: false
      t.integer :priority, default: 0, null: false
      t.jsonb :conditions, null: false, default: {}
      t.references :agent, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :routing_rules, [ :user_id, :active ]
  end
end
