class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :name, null: false
      t.text :description
      t.text :body
      t.boolean :shared, null: false, default: false
      t.timestamps
    end

    add_index :skills, [:user_id, :name], unique: true
  end
end