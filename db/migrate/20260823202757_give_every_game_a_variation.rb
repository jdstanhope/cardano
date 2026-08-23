class GiveEveryGameAVariation < ActiveRecord::Migration[8.1]
  # Games created before variation 01 became automatic have none, and a game with no
  # variation cannot hold reel strips or a paytable — so it cannot be worked on at all.
  # Written in SQL rather than through the model so it does not depend on validations
  # or callbacks that may change later.
  def up
    execute <<~SQL
      INSERT INTO variations (game_id, number, created_at, updated_at)
      SELECT games.id, 1, NOW(), NOW()
      FROM games
      LEFT JOIN variations ON variations.game_id = games.id
      WHERE variations.id IS NULL
    SQL
  end

  # Deliberately irreversible.
  #
  # A variation numbered 01 created by this migration is indistinguishable from one
  # the application created when its game was made — same columns, same values. A
  # down that deleted "empty 01 variations" was written first and tried on real data:
  # it removed one this migration had never touched. There is no schema change to
  # undo, so refusing is safer than guessing.
  def down
    raise ActiveRecord::IrreversibleMigration,
      "Cannot tell a backfilled variation 01 from one the application created"
  end
end
