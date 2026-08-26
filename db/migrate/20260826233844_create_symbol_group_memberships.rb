class CreateSymbolGroupMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :symbol_group_memberships do |t|
      t.references :symbol_group, null: false, foreign_key: { on_delete: :cascade }
      t.references :game_symbol, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    # A symbol belongs to a group once. It may belong to several groups, and a group
    # holds several symbols, which is why this is a table rather than a column.
    add_index :symbol_group_memberships, [ :symbol_group_id, :game_symbol_id ],
              unique: true, name: "index_memberships_on_group_and_symbol"
  end
end
