class CreateWildExclusions < ActiveRecord::Migration[8.1]
  # A wild substitutes for everything except the symbols named here — a deny list
  # rather than an allow list, so a symbol added later is substitutable by default.
  # An allow list would silently exclude it and produce an RTP that is too low while
  # looking entirely reasonable.
  #
  # Both sides point at game_symbols, so the foreign keys name their target
  # explicitly. Deleting either symbol removes the exclusion with it.
  def change
    create_table :wild_exclusions do |t|
      t.references :wild, null: false, foreign_key: { to_table: :game_symbols, on_delete: :cascade }
      t.references :excluded, null: false, foreign_key: { to_table: :game_symbols, on_delete: :cascade }

      t.timestamps
    end

    add_index :wild_exclusions, [ :wild_id, :excluded_id ], unique: true
  end
end
