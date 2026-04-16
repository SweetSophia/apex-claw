class CreateAgentRateLimits < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_rate_limits do |t|
      t.references :agent, null: false, foreign_key: true, index: { unique: true }
      t.integer :window_seconds, null: false, default: 60
      t.integer :max_requests, null: false, default: 120

      t.timestamps
    end
  end
end
