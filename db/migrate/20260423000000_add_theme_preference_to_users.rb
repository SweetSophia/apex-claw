class AddThemePreferenceToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :theme_preference, :string, default: "dark", null: false
    add_index :users, :theme_preference
  end

  def down
    remove_column :users, :theme_preference
  end
end
