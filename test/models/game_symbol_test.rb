require "test_helper"

class GameSymbolTest < ActiveSupport::TestCase
  test "requires a code and a position" do
    symbol = GameSymbol.new(game: games(:five_by_three))

    assert_not symbol.valid?
    assert symbol.errors.of_kind?(:code, :blank)
    assert symbol.errors.of_kind?(:position, :blank)
  end

  test "codes are unique within a game, and case is not a way around that" do
    taken = game_symbols(:ace)

    assert_not GameSymbol.new(game: taken.game, code: taken.code, position: 9).valid?
    assert_not GameSymbol.new(game: taken.game, code: taken.code.downcase, position: 9).valid?
  end

  test "the same code may appear in a different game" do
    other = Game.create!(user: users(:one), name: "Another", reel_count: 5, row_count: 3)

    assert GameSymbol.new(game: other, code: game_symbols(:ace).code, position: 1).valid?
  end

  test "falls back to the code when no name is given" do
    assert_equal "Ace", game_symbols(:ace).display_name
    assert_equal "Q", GameSymbol.new(code: "Q").display_name
  end

  test "does not shadow Ruby's Symbol" do
    assert_equal ::Symbol, :a.class
    assert_not_equal ::Symbol, GameSymbol
  end
end
