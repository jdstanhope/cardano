class AddWildToGameSymbols < ActiveRecord::Migration[8.1]
  def change
    add_column :game_symbols, :wild, :boolean, null: false, default: false

    # A game has at most one wild, and may have none. A partial unique index lets
    # the database hold that rule rather than trusting every path through the model.
    add_index :game_symbols, :game_id, unique: true, where: "wild", name: "index_one_wild_per_game"
  end
end
