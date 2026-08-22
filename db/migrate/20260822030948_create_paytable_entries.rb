class CreatePaytableEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :paytable_entries do |t|
      t.references :variation, null: false, foreign_key: true
      t.references :game_symbol, null: false, foreign_key: true

      # How many matching symbols, and what that pays in credits per unit of
      # line stake. Integers, so the figures stay exact.
      t.integer :count, null: false
      t.integer :payout, null: false

      t.timestamps
    end

    add_index :paytable_entries, [ :variation_id, :game_symbol_id, :count ],
              unique: true, name: "index_paytable_entries_on_variation_symbol_count"
  end
end
