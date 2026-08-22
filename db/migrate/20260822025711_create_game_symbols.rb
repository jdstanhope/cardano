class CreateGameSymbols < ActiveRecord::Migration[8.1]
  def change
    create_table :game_symbols do |t|
      t.references :game, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name
      t.integer :position, null: false

      t.timestamps
    end

    add_index :game_symbols, [ :game_id, :code ], unique: true
  end
end
