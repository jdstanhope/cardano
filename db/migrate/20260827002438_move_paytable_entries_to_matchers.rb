class MovePaytableEntriesToMatchers < ActiveRecord::Migration[8.1]
  # Turns each existing entry into a sequence: a count of N becomes N matchers of the
  # same symbol. Written in SQL so it does not depend on validations or callbacks that
  # will change in this very commit.
  def up
    execute <<~SQL
      INSERT INTO paytable_matchers (paytable_entry_id, position, game_symbol_id, created_at, updated_at)
      SELECT entries.id, positions.position, entries.game_symbol_id, NOW(), NOW()
      FROM paytable_entries entries
      JOIN LATERAL generate_series(1, entries.count) AS positions(position) ON TRUE
    SQL

    remove_index :paytable_entries, name: "index_paytable_entries_on_variation_symbol_count"
    remove_column :paytable_entries, :count
    remove_column :paytable_entries, :game_symbol_id
  end

  # Only reverses entries whose matchers are all the same symbol, which is everything
  # that exists at the time of writing. A mixed combination has no (symbol, count) to
  # go back to, so it is dropped rather than silently turned into something it is not.
  def down
    add_column :paytable_entries, :count, :integer
    add_reference :paytable_entries, :game_symbol, foreign_key: true

    execute <<~SQL
      UPDATE paytable_entries SET
        count = counted.total,
        game_symbol_id = counted.game_symbol_id
      FROM (
        SELECT paytable_entry_id, COUNT(*) AS total, MIN(game_symbol_id) AS game_symbol_id
        FROM paytable_matchers
        WHERE symbol_group_id IS NULL
        GROUP BY paytable_entry_id
        HAVING COUNT(DISTINCT game_symbol_id) = 1
      ) AS counted
      WHERE paytable_entries.id = counted.paytable_entry_id
    SQL

    execute "DELETE FROM paytable_entries WHERE count IS NULL OR game_symbol_id IS NULL"

    change_column_null :paytable_entries, :count, false
    change_column_null :paytable_entries, :game_symbol_id, false
    add_index :paytable_entries, [ :variation_id, :game_symbol_id, :count ],
              unique: true, name: "index_paytable_entries_on_variation_symbol_count"
  end
end
