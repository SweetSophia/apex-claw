class CreateTaskArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :task_artifacts do |t|
      t.references :task, null: false, foreign_key: true, index: true
      t.string :filename, null: false
      t.string :content_type, null: false
      t.integer :size, null: false
      t.string :storage_path
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
