class CreateVariations < ActiveRecord::Migration[8.1]
  def change
    create_table :variations do |t|
      t.references :game, null: false, foreign_key: true
      t.string :name, null: false

      # Basis points: 9600 is 96.00%. Integers, because the whole reason for
      # evaluating exhaustively is to produce exact figures.
      t.integer :target_rtp_min
      t.integer :target_rtp_max

      t.timestamps
    end

    add_index :variations, [ :game_id, :name ], unique: true
  end
end
