require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "requires a name and a window" do
    game = Game.new(user: users(:one))

    assert_not game.valid?
    assert game.errors.of_kind?(:name, :blank)
    assert game.errors.of_kind?(:reel_count, :blank)
    assert game.errors.of_kind?(:row_count, :blank)
  end

  test "requires a window with at least one reel and one row" do
    game = Game.new(user: users(:one), name: "Empty", reel_count: 0, row_count: 0)

    assert_not game.valid?
    assert game.errors.of_kind?(:reel_count, :greater_than)
    assert game.errors.of_kind?(:row_count, :greater_than)
  end

  test "names are unique for one person but not across people" do
    taken = games(:five_by_three)

    duplicate = Game.new(user: taken.user, name: taken.name, reel_count: 5, row_count: 3)
    assert_not duplicate.valid?

    someone_else = Game.new(user: users(:two), name: taken.name, reel_count: 5, row_count: 3)
    assert someone_else.valid?
  end

  test "row indices are centred on zero, descending from the top" do
    assert_equal [ 1, 0, -1 ], games(:five_by_three).row_indices
    assert_equal [ 1, 0, -1, -2 ], games(:five_by_four).row_indices
  end

  test "an even window puts one row above centre and two below" do
    assert_equal 1, games(:five_by_four).top_row
    assert_equal(-2, games(:five_by_four).bottom_row)
  end

  test "row indices for other window heights" do
    { 1 => [ 0 ],
      2 => [ 0, -1 ],
      5 => [ 2, 1, 0, -1, -2 ],
      6 => [ 2, 1, 0, -1, -2, -3 ] }.each do |height, expected|
      game = Game.new(reel_count: 5, row_count: height)
      assert_equal expected, game.row_indices, "#{height} rows"
    end
  end

  test "zero is a row in every window, which is what makes the centre line portable" do
    (1..8).each do |height|
      assert_includes Game.new(reel_count: 5, row_count: height).row_indices, 0
    end
  end

  test "converts a row index to an offset from the top for rendering" do
    game = games(:five_by_three)

    assert_equal 0, game.offset_from_top(1)
    assert_equal 1, game.offset_from_top(0)
    assert_equal 2, game.offset_from_top(-1)
  end

  test "is reachable from the person who owns it" do
    # current_user.games is the intended entry point for every controller, so the
    # association has to exist before one is written.
    assert_includes users(:one).games, games(:five_by_three)
  end

  test "a new game arrives with variation 01" do
    game = users(:one).games.create!(name: "Fresh", reel_count: 5, row_count: 3)

    assert_equal [ 1 ], game.variations.map(&:number)
    assert_equal "01", game.variations.first.label
  end

  test "the default variation is only created for a new game" do
    game = users(:one).games.create!(name: "Fresh", reel_count: 5, row_count: 3)

    assert_no_difference -> { game.variations.count } do
      game.update!(name: "Renamed")
    end
  end

  test "destroying a game takes everything beneath it, in an order Postgres accepts" do
    game = games(:five_by_three)
    assert game.symbols.any? && game.paylines.any? && game.variations.any?
    assert PaytableEntry.where(variation: game.variations).any?,
      "the cascade is only interesting when a paytable entry references a symbol"

    assert_nothing_raised { game.destroy! }

    assert_empty GameSymbol.where(game_id: game.id)
    assert_empty Payline.where(game_id: game.id)
    assert_empty Variation.where(game_id: game.id)
  end

  test "owns its symbols, paylines, and variations" do
    game = games(:five_by_three)

    assert_includes game.symbols, game_symbols(:ace)
    assert_includes game.paylines, paylines(:centre)
    assert_includes game.variations, variations(:ninety_six)
  end
end
