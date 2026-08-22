class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false

      # The reel window: two integers rather than a table of its own.
      t.integer :reel_count, null: false
      t.integer :row_count, null: false

      t.timestamps
    end

    add_index :games, [ :user_id, :name ], unique: true
  end
end
