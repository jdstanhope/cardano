require "test_helper"

class WinMechanicTest < ActiveSupport::TestCase
  setup do
    @game = games(:five_by_three)
    @game.paylines.destroy_all
    @a = game_symbols(:ace)
    @k = game_symbols(:king)
    @wild = game_symbols(:jack)
    @wild.update!(wild: true)

    # A x3 pays 5, A x4 pays 25; K x3 pays 2. Deliberately different, so "the best
    # interpretation" is a real choice rather than a tie.
    @paytable = { @a => { 3 => 5, 4 => 25, 5 => 100 }, @k => { 3 => 2 } }
  end

  # Columns are given top to bottom, matching how the window is read on screen.
  def window(*columns) = ReelWindow.new(@game, columns)

  def centre_line
    @game.paylines.create!(position: 1, rows: [ 0, 0, 0, 0, 0 ])
  end

  # --- lines -----------------------------------------------------------------

  test "a line pays the run that starts on the leftmost reel" do
    centre_line
    mechanic = WinMechanic.for(@game)

    wins = mechanic.wins(window([ @k, @a, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), @paytable)

    assert_equal 1, wins.length
    assert_equal @a, wins.first.symbol
    assert_equal 3, wins.first.length
    assert_equal 1, wins.first.times, "a payline win occurs once"
  end

  test "a run that does not reach the leftmost reel does not pay" do
    centre_line
    mechanic = WinMechanic.for(@game)

    # A on reels 2, 3 and 4 only.
    wins = mechanic.wins(window([ @k, @k, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ]), @paytable)

    assert_empty wins
  end

  test "a wild extends a run for the symbol it substitutes for" do
    centre_line
    mechanic = WinMechanic.for(@game)

    wins = mechanic.wins(window([ @k, @a, @k ], [ @k, @wild, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ]), @paytable)

    assert_equal 4, wins.first.length, "the wild stands in for the ace"
    assert_equal @a, wins.first.symbol
  end

  test "a wild does not extend a run for a symbol it is told to leave alone" do
    centre_line
    @wild.excluded_symbols << @a
    mechanic = WinMechanic.for(@game)

    wins = mechanic.wins(window([ @k, @a, @k ], [ @k, @wild, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ]), @paytable)

    assert_empty wins, "the run stops at the wild, leaving one ace, which does not pay"
  end

  # The rule that a naive implementation gets wrong.
  test "a line pays its best reading once, not every reading" do
    centre_line
    mechanic = WinMechanic.for(@game)

    # W W A A K reads as A x4 (25) and, if K were substitutable, as K x2 (nothing).
    # Only the best-paying reading may count.
    wins = mechanic.wins(window([ @k, @wild, @k ], [ @k, @wild, @k ], [ @k, @a, @k ], [ @k, @a, @k ], [ @k, @k, @k ]), @paytable)

    assert_equal 1, wins.length, "one line pays once"
    assert_equal 25, wins.sum { |win| win.payout(@paytable) }
  end

  test "the stake is one unit per payline" do
    3.times { |i| @game.paylines.create!(position: i + 1, rows: [ 0, 0, 0, 0, 0 ].dup.tap { |r| r[0] = @game.row_indices[i] }) }

    assert_equal 3, WinMechanic.for(@game).stake_units
  end

  # --- ways ------------------------------------------------------------------

  test "ways counts every arrangement, not every line" do
    @game.update!(win_mechanic: "ways")
    mechanic = WinMechanic.for(@game)

    # Two aces on reel 1, one on reel 2, three on reel 3: 2 x 1 x 3 = 6 ways of A x3.
    wins = mechanic.wins(window([ @a, @a, @k ], [ @k, @a, @k ], [ @a, @a, @a ], [ @k, @k, @k ], [ @k, @k, @k ]), @paytable)

    assert_equal 1, wins.length
    assert_equal 3, wins.first.length
    assert_equal 6, wins.first.times
    assert_equal 30, wins.first.payout(@paytable), "six ways at five each"
  end

  test "every winning symbol pays in a ways game" do
    @game.update!(win_mechanic: "ways")
    mechanic = WinMechanic.for(@game)

    # A x3 on the top row and K x3 on the bottom, both reaching reel 3.
    wins = mechanic.wins(window([ @a, @k, @k ], [ @a, @k, @k ], [ @a, @k, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), @paytable)

    assert_equal 2, wins.map(&:symbol).uniq.length,
      "unlike a payline, a ways spin can pay several symbols at once"
  end

  test "a wild multiplies the ways rather than adding one" do
    @game.update!(win_mechanic: "ways")
    mechanic = WinMechanic.for(@game)

    # Reel 2 shows an ace and a wild: two matching positions, not one.
    wins = mechanic.wins(window([ @a, @k, @k ], [ @a, @wild, @k ], [ @a, @k, @k ], [ @k, @k, @k ], [ @k, @k, @k ]), @paytable)

    assert_equal 2, wins.first.times, "1 x 2 x 1"
  end

  test "a run longer than the paytable prices pays the longest count it does price" do
    centre_line
    mechanic = WinMechanic.for(@game)

    # Five kings, but the paytable only names K x3.
    wins = mechanic.wins(window(*Array.new(5) { [ @a, @k, @a ] }), @paytable)

    assert_equal 1, wins.length
    assert_equal @k, wins.first.symbol
    assert_equal 3, wins.first.length, "paid as three of a kind, not dropped for lacking a five"
    assert_equal 2, wins.first.payout(@paytable)
  end

  test "ways counts arrangements over the reels that form the paid combination" do
    @game.update!(win_mechanic: "ways")
    mechanic = WinMechanic.for(@game)

    # Kings on every position of every reel: the run reaches five, but only x3 is
    # priced, so the ways are counted over three reels rather than five.
    wins = mechanic.wins(window(*Array.new(5) { [ @k, @k, @k ] }), @paytable)

    assert_equal 3, wins.first.length
    assert_equal 27, wins.first.times, "3 x 3 x 3, not 3^5"
  end

  test "the stake is one unit per way" do
    @game.update!(win_mechanic: "ways")

    assert_equal 243, WinMechanic.for(@game).stake_units, "3 rows across 5 reels"
  end

  test "the same window pays differently under each mechanic" do
    centre_line
    shown = [ [ @a, @a, @k ], [ @k, @a, @k ], [ @a, @a, @a ], [ @k, @k, @k ], [ @k, @k, @k ] ]

    by_lines = WinMechanic.for(@game).wins(window(*shown), @paytable).sum { |w| w.payout(@paytable) }

    # A ways game has no paylines, and the model refuses to hold both.
    @game.paylines.destroy_all
    @game.update!(win_mechanic: "ways")
    by_ways = WinMechanic.for(@game).wins(window(*shown), @paytable).sum { |w| w.payout(@paytable) }

    assert_equal 5, by_lines, "one payline, one win"
    assert_equal 30, by_ways, "six arrangements of the same three symbols"
    assert_not_equal by_lines, by_ways
  end
end
