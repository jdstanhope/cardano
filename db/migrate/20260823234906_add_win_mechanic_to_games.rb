class AddWinMechanicToGames < ActiveRecord::Migration[8.1]
  # How a game selects the combinations it offers to the paytable. Existing games all
  # pay by lines, which is the only thing that existed before this.
  def change
    add_column :games, :win_mechanic, :string, null: false, default: "lines"
  end
end
