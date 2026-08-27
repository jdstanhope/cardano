require "test_helper"

class WildSymbolTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
    @unused = game_symbols(:jack)   # used by nothing
    @paying = game_symbols(:ten)    # paid for, never on a strip
  end

  test "a game may have no wild" do
    assert_predicate @game.symbols.where(wild: true), :empty?
    assert @game.valid?
  end

  test "a symbol can be marked wild" do
    assert @unused.update(wild: true)
    assert_equal @unused, @game.reload.wild_symbol
  end

  test "a game can have only one wild" do
    @unused.update!(wild: true)

    second = @game.symbols.new(code: "W2", position: 9, wild: true)

    assert_not second.valid?
    assert_match(/already the wild/i, second.errors[:base].to_sentence)
  end

  test "the one wild rule is per game, not global" do
    @unused.update!(wild: true)

    assert games(:other_game).symbols.new(code: "W", position: 9, wild: true).valid?
  end

  test "the database refuses a second wild even if the model is bypassed" do
    @unused.update!(wild: true)

    assert_raises ActiveRecord::RecordNotUnique do
      @game.symbols.insert!({ code: "W2", position: 9, wild: true, created_at: Time.current, updated_at: Time.current })
    end
  end

  test "a symbol named wild is recognised when added" do
    symbol = @game.symbols.create!(code: "W", name: "Wild", position: 9)

    assert_predicate symbol, :wild?
  end

  test "recognition ignores case and surrounding space" do
    assert_predicate @game.symbols.create!(code: "W", name: "  wILd  ", position: 9), :wild?
  end

  test "a name that merely contains wild is not swept up" do
    assert_not_predicate @game.symbols.create!(code: "WC", name: "Wildcat", position: 9), :wild?
  end

  test "recognition does not override the one wild rule" do
    @unused.update!(wild: true)

    second = @game.symbols.new(code: "W", name: "Wild", position: 9)

    assert_not second.valid?,
      "a second symbol named Wild should be rejected rather than quietly arriving unmarked"
  end

  test "marking a symbol that still pays is refused, naming what it pays" do
    assert_not @paying.update(wild: true)

    message = @paying.errors[:base].to_sentence
    assert_match(/x3/, message)
    assert_match(/clear/i, message)
  end

  test "a wild cannot be given a paytable entry" do
    @unused.update!(wild: true)

    entry = variations(:ninety_six).paytable_entries.new(payout: 5)
    3.times { |index| entry.matchers.build(position: index + 1, game_symbol: @unused) }

    assert_not entry.valid?
    assert_match(/wild/i, entry.matchers.first.errors[:game_symbol].to_sentence)
  end

  test "unmarking a wild that is not named wild is allowed, and frees the slot" do
    @unused.update!(wild: true)
    assert @unused.update(wild: false)

    assert_nil @game.reload.wild_symbol
    assert @game.symbols.new(code: "W", position: 9, wild: true).valid?
  end

  test "a symbol named wild stays wild, because the name decides it" do
    named = @game.symbols.create!(code: "W", name: "Wild", position: 9)

    named.update(wild: false)

    assert_predicate named.reload, :wild?,
      "the name says it is the wild, so unmarking cannot quietly disagree with it"
  end

  test "no other symbol can be offered as wild while one exists" do
    assert_predicate @game, :wild_available?

    @unused.update!(wild: true)

    assert_not_predicate @game.reload, :wild_available?
  end
end
