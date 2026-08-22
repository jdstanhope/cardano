class ReplaceVariationNameWithNumber < ActiveRecord::Migration[8.1]
  def up
    add_column :variations, :number, :integer

    # Numbers are assigned in creation order per game. There is no production data,
    # but doing this properly keeps the migration honest if any exists anywhere.
    execute <<~SQL
      UPDATE variations SET number = ordered.row_number
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY game_id ORDER BY id) AS row_number
        FROM variations
      ) AS ordered
      WHERE variations.id = ordered.id
    SQL

    change_column_null :variations, :number, false
    remove_index :variations, column: [ :game_id, :name ]
    remove_column :variations, :name
    add_index :variations, [ :game_id, :number ], unique: true
  end

  def down
    add_column :variations, :name, :string
    execute "UPDATE variations SET name = LPAD(number::text, 2, '0')"
    change_column_null :variations, :name, false
    remove_index :variations, column: [ :game_id, :number ]
    remove_column :variations, :number
    add_index :variations, [ :game_id, :name ], unique: true
  end
end
