require "test_helper"

class WinMechanicTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
    @game.paylines.destroy_all
    @variation = variations(:ninety_six)
    @variation.paytable_entries.destroy_all

    @a = game_symbols(:ace)
    @k = game_symbols(:king)
    @wild = game_symbols(:jack)
    @wild.update!(wild: true)
  end

  # A combination is a sequence of matchers: N of a kind is one symbol repeated.
  def pays(payout, *things)
    entry = @variation.paytable_entries.new(payout: payout)
    things.each_with_index do |thing, index|
      key = thing.is_a?(SymbolGroup) ? :symbol_group : :game_symbol
      entry.matchers.build(position: index + 1, key => thing)
    end
    entry.save!
    entry
  end

  def entries = @variation.reload.paytable

  def window(*columns) = ReelWindow.new(@game, columns)

  def centre_line = @game.paylines.create!(position: 1, rows: [ 0, 0, 0, 0, 0 ])

  # --- lines -----------------------------------------------------------------

  test "a line pays a combination that starts on the leftmost reel" do
    centre_line
    pays 5, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window([ @k, @a, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), entries)

    assert_equal 1, wins.length
    assert_equal 5, wins.first.payout
    assert_equal 1, wins.first.times, "a payline win occurs once"
  end

  test "a combination that does not reach the leftmost reel does not pay" do
    centre_line
    pays 5, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window([ @k, @k, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ]), entries)

    assert_empty wins
  end

  test "a wild satisfies a position naming the symbol it substitutes for" do
    centre_line
    pays 25, @a, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window([ @k, @a, @k ], [ @k, @wild, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ]), entries)

    assert_equal 25, wins.first.payout
  end

  test "a wild told to leave a symbol alone does not satisfy a position naming it" do
    centre_line
    @wild.excluded_symbols << @a
    pays 25, @a, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window([ @k, @a, @k ], [ @k, @wild, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ]), entries)

    assert_empty wins
  end

  test "a line pays its best reading once, not every reading" do
    centre_line
    sevens = @game.symbol_groups.create!(name: "Sevens", position: 1)
    sevens.game_symbols << @a
    pays 5, @a, @a, @a
    pays 2, sevens, sevens, sevens

    wins = WinMechanic.for(@game).wins(window(*Array.new(5) { [ @k, @a, @k ] }), entries)

    assert_equal 1, wins.length, "three aces are also three sevens, and that is one outcome"
    assert_equal 5, wins.sum(&:payout), "the better reading pays"
  end

  test "a longer combination supersedes a shorter one without a rule about lengths" do
    centre_line
    pays 5, @a, @a, @a
    pays 100, @a, @a, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window(*Array.new(5) { [ @k, @a, @k ] }), entries)

    assert_equal 100, wins.sum(&:payout)
  end

  test "a shorter combination still pays when the longer one does not reach" do
    centre_line
    pays 5, @a, @a, @a
    pays 100, @a, @a, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window([ @k, @a, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), entries)

    assert_equal 5, wins.sum(&:payout)
  end

  test "a group satisfies a position for any of its members" do
    centre_line
    bars = @game.symbol_groups.create!(name: "Bars", position: 1)
    bars.game_symbols << [ @a, @k ]
    pays 3, bars, bars, bars

    wins = WinMechanic.for(@game).wins(window([ @k, @a, @k ], [ @k, @k, @k ], [ @k, @a, @k ], [ @k, game_symbols(:queen), @k ], [ @k, @k, @k ]), entries)

    assert_equal 3, wins.sum(&:payout), "an ace, a king and an ace are all bars"
  end

  test "a wild satisfies a group when it substitutes for a member" do
    centre_line
    bars = @game.symbol_groups.create!(name: "Bars", position: 1)
    bars.game_symbols << @a
    pays 3, bars, bars, bars

    wins = WinMechanic.for(@game).wins(window([ @k, @a, @k ], [ @k, @wild, @k ], [ @k, @a, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), entries)

    assert_equal 3, wins.sum(&:payout)
  end

  test "a combination may mix symbols and groups in order" do
    centre_line
    sevens = @game.symbol_groups.create!(name: "Sevens", position: 1)
    sevens.game_symbols << @k
    pays 50, @a, sevens, @a

    wins = WinMechanic.for(@game).wins(window([ @k, @a, @k ], [ @k, @k, @k ], [ @k, @a, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), entries)

    assert_equal 50, wins.sum(&:payout), "ace, then any seven, then ace"
  end

  test "the stake is one unit per payline" do
    3.times { |i| @game.paylines.create!(position: i + 1, rows: [ @game.row_indices[i] ] * 5) }

    assert_equal 3, WinMechanic.for(@game).stake_units
  end

  # --- ways ------------------------------------------------------------------

  test "ways counts every arrangement" do
    @game.update!(win_mechanic: "ways")
    pays 5, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window([ @a, @a, @k ], [ @k, @a, @k ], [ @a, @a, @a ], [ @k, @k, @k ], [ @k, @k, @k ]), entries)

    assert_equal 6, wins.first.times, "2 x 1 x 3"
    assert_equal 30, wins.first.payout
  end

  test "several combinations pay at once in a ways game" do
    @game.update!(win_mechanic: "ways")
    pays 5, @a, @a, @a
    pays 2, @k, @k, @k

    wins = WinMechanic.for(@game).wins(window([ @a, @k, @k ], [ @a, @k, @k ], [ @a, @k, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), entries)

    assert_equal 2, wins.length, "unlike a payline, a ways spin can pay several combinations"
  end

  # The rule that keeps ways from counting one outcome twice.
  test "ways pays the best match per opening matcher, not every match" do
    @game.update!(win_mechanic: "ways")
    pays 5, @a, @a, @a
    pays 100, @a, @a, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window(*Array.new(5) { [ @a, @k, @k ] }), entries)

    assert_equal 1, wins.length, "five aces also match the three ace combination, and that is one outcome"
    assert_equal 100, wins.sum(&:payout)
  end

  test "a wild multiplies the arrangements rather than adding one" do
    @game.update!(win_mechanic: "ways")
    pays 5, @a, @a, @a

    wins = WinMechanic.for(@game).wins(window([ @a, @k, @k ], [ @a, @wild, @k ], [ @a, @k, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), entries)

    assert_equal 2, wins.first.times, "1 x 2 x 1"
  end

  test "the stake is one unit per way" do
    @game.update!(win_mechanic: "ways")

    assert_equal 243, WinMechanic.for(@game).stake_units, "3 rows across 5 reels"
  end

  test "the same window pays differently under each mechanic" do
    centre_line
    pays 5, @a, @a, @a
    shown = [ [ @a, @a, @k ], [ @k, @a, @k ], [ @a, @a, @a ], [ @k, @k, @k ], [ @k, @k, @k ] ]

    by_lines = WinMechanic.for(@game).wins(window(*shown), entries).sum(&:payout)

    @game.paylines.destroy_all
    @game.update!(win_mechanic: "ways")
    by_ways = WinMechanic.for(@game).wins(window(*shown), entries).sum(&:payout)

    assert_equal 5, by_lines
    assert_equal 30, by_ways
  end
end
