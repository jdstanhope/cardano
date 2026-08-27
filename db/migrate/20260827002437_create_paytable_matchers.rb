class CreatePaytableMatchers < ActiveRecord::Migration[8.1]
  # One position in a paytable combination, matching either a specific symbol or a
  # group. Exactly one of the two is set, which the model enforces and the check
  # constraint here guarantees whatever writes the row.
  def change
    create_table :paytable_matchers do |t|
      t.references :paytable_entry, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false
      t.references :game_symbol, foreign_key: { on_delete: :cascade }
      t.references :symbol_group, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :paytable_matchers, [ :paytable_entry_id, :position ], unique: true

    add_check_constraint :paytable_matchers,
      "(game_symbol_id IS NOT NULL) <> (symbol_group_id IS NOT NULL)",
      name: "matcher_names_exactly_one_of_symbol_or_group"
  end
end
