require "test_helper"

# Two rules pull against each other here, and a change to one can silently undo the
# other, so both directions are asserted together.
#
#   - a symbol removed on its own is refused while anything uses it
#   - a symbol removed as part of its game goes regardless, or destroying a game
#     with a paytable fails at the database
class GameSymbolRemovalTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
    # `ten` is paid for but never lands on a strip; `jack` is used by nothing.
    @used_by_paytable = game_symbols(:ten)
    @unused = game_symbols(:jack)
  end

  test "an unused symbol can be removed" do
    assert_difference -> { GameSymbol.count }, -1 do
      assert @unused.destroy
    end
  end

  test "a symbol a paytable entry pays for cannot be removed" do
    assert @used_by_paytable.paytable_entries.any?

    assert_no_difference -> { GameSymbol.count } do
      assert_not @used_by_paytable.destroy
    end

    assert_match(/paytable/i, @used_by_paytable.errors[:base].to_sentence)
  end

  test "a symbol a reel strip lands on cannot be removed" do
    king = game_symbols(:king)
    assert_includes reel_strips(:reel_one).symbols, king.code

    assert_no_difference -> { GameSymbol.count } do
      assert_not king.destroy
    end

    assert_match(/reel/i, king.errors[:base].to_sentence)
  end

  # The guard has to run before `dependent: :destroy` does. Without prepend: true the
  # entries are deleted first, the guard then finds nothing to object to, and the
  # symbol goes with its paytable — silently.
  test "a refused removal leaves the paytable entries untouched" do
    entries = @used_by_paytable.paytable_entries.count
    assert entries.positive?

    @used_by_paytable.destroy

    assert_equal entries, @used_by_paytable.paytable_entries.reload.count,
      "refusing the removal must not have destroyed the entries on the way"
  end

  test "the refusal names what is using the symbol" do
    king = game_symbols(:king)
    king.destroy

    message = king.errors[:base].to_sentence
    assert_match(/01/, message, "the variation should be named by its label")
  end

  test "a symbol in another game's strip does not block removal here" do
    # `other_game` has its own A. Nothing in this game uses it.
    foreign = game_symbols(:foreign_ace)

    assert_difference -> { GameSymbol.count }, -1 do
      assert foreign.destroy
    end
  end

  # The other direction. #31 fixed destroying a game by cascading paytable entries
  # through the symbol; a guard that applied here too would reintroduce that bug.
  test "destroying a game still removes symbols that are in use" do
    assert game_symbols(:ace).paytable_entries.any?
    assert @used_by_paytable.paytable_entries.any?

    assert_nothing_raised { @game.destroy! }

    assert_empty GameSymbol.where(game_id: @game.id)
    assert_empty PaytableEntry.where(game_symbol_id: game_symbols(:ace).id)
  end
end
