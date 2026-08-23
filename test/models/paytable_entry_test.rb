require "test_helper"

class PaytableEntryTest < ActiveSupport::TestCase
  setup do
    @variation = variations(:ninety_six)
  end

  test "requires a count and a payout" do
    entry = PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king))

    assert_not entry.valid?
    assert entry.errors.of_kind?(:count, :blank)
    assert entry.errors.of_kind?(:payout, :blank)
  end

  test "nothing pays for a single symbol" do
    assert_not PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king), count: 1, payout: 1).valid?,
      "no game pays one of a kind, so a count of 1 is a mistake rather than an unusual design"
  end

  test "two of a kind is allowed, since some games do pay from two" do
    assert PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king), count: 2, payout: 1).valid?
  end

  test "the count must be a number of symbols the game can show" do
    assert PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king), count: 5, payout: 1).valid?
    assert_not PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king), count: 6, payout: 1).valid?,
      "a five reel game cannot show six of a kind"
    assert_not PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king), count: 0, payout: 1).valid?
  end

  test "a payout is a positive whole number of credits" do
    assert_not PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king), count: 3, payout: 0).valid?
    assert_not PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:king), count: 3, payout: -5).valid?
  end

  test "one entry per symbol and count" do
    taken = paytable_entries(:ace_three)
    duplicate = PaytableEntry.new(variation: taken.variation, game_symbol: taken.game_symbol, count: taken.count, payout: 99)

    assert_not duplicate.valid?
  end

  test "the same symbol may pay at several counts" do
    assert_equal 2, @variation.paytable_entries.where(game_symbol: game_symbols(:ace)).count
  end

  test "rejects a symbol belonging to a different game" do
    entry = PaytableEntry.new(variation: @variation, game_symbol: game_symbols(:foreign_ace), count: 3, payout: 5)

    assert_not entry.valid?, "a symbol from another game can never land in this one"
    assert_match(/game/i, entry.errors[:game_symbol].to_sentence)
  end
end
