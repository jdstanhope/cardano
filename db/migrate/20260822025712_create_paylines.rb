class CreatePaylines < ActiveRecord::Migration[8.1]
  def change
    create_table :paylines do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :position, null: false

      # One row index per reel, centred on zero. [0, 0, 0, 0, 0] is the middle
      # line for any window height. See Game#row_range.
      t.integer :rows, array: true, null: false, default: []

      t.timestamps
    end

    add_index :paylines, [ :game_id, :position ], unique: true
  end
end
