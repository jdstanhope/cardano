class CreateSymbolGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :symbol_groups do |t|
      t.references :game, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :symbol_groups, [ :game_id, :name ], unique: true
  end
end
