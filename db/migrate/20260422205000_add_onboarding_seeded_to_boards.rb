class AddOnboardingSeededToBoards < ActiveRecord::Migration[8.1]
  def up
    add_column :boards, :onboarding_seeded, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE boards
      SET onboarding_seeded = TRUE
      WHERE name = 'Getting Started'
        AND icon = '🚀'
    SQL
  end

  def down
    remove_column :boards, :onboarding_seeded
  end
end
