class CreateCountersTable < ActiveRecord::Migration[8.0]
  def up
    create_table :counters do |t|
      t.string :key, null: false
      t.integer :count, default: 0, null: false
      t.integer :expires_at, null: false
      t.timestamps
    end
    add_index :counters, :key, unique: true
    add_index :counters, :expires_at
  end

  def down
    drop_table :counters
  end
end
