class CreateReelStrips < ActiveRecord::Migration[8.1]
  def change
    create_table :reel_strips do |t|
      t.references :variation, null: false, foreign_key: true

      # Which reel this is, 1-based, within the game's reel_count.
      t.integer :position, null: false

      # The ordered stops, held as symbol codes. Arrays cannot carry a foreign
      # key, so ReelStrip validates the codes against the game's symbols.
      t.string :symbols, array: true, null: false, default: []

      t.timestamps
    end

    add_index :reel_strips, [ :variation_id, :position ], unique: true
  end
end
