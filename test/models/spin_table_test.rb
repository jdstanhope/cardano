require "test_helper"

# The compiled evaluator, and the tests that bind it to the one already proven.
#
# A second way of evaluating a spin is only acceptable while something holds it to the
# first, so both games here are checked exhaustively rather than sampled.
#
# Two games, because one is not enough. Red White & Blue is the published machine and the
# larger space, but it is three reels of one row where every combination is exactly three
# long — so it cannot exercise a combination shorter than the reels, a wild, or a payline
# that leaves the centre row. Mutating those rules leaves it green. The second game is
# tiny and deliberately does all three.
class SpinTableTest < ActiveSupport::TestCase
  COMBINATIONS = SampleGame::RedWhiteAndBlue::COMBINATIONS

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "the same seed spins the same sequence" do
    first = spins_from(SpinTable.for(@variation), seed: 4)
    second = spins_from(SpinTable.for(@variation), seed: 4)

    assert_equal first, second
    assert first.any?(&:positive?),
      "a run that never paid would satisfy this while proving nothing"
  end

  test "the compiled table pays what the mechanic pays, on every outcome there is" do
    assert_agrees_with_the_mechanic @variation, outcomes: COMBINATIONS
  end

  test "the compiled table agrees where combinations are short, wilds land and lines bend" do
    assert_agrees_with_the_mechanic mixed_variation, outcomes: 64
  end

  private
    def spins_from(table, seed:, count: 200)
      rng = Random.new(seed)
      count.times.map { table.spin(rng) }
    end

    # Walks every stop the reels can take and insists the two routes agree.
    #
    # The window is built here rather than asked of SpinTable, so how a stop maps to the
    # rows on screen is checked on both sides instead of agreed between them.
    def assert_agrees_with_the_mechanic(variation, outcomes:)
      game = variation.game
      table = SpinTable.for(variation)
      mechanic = WinMechanic.for(game)
      entries = variation.paytable
      strips = variation.reel_strips.sort_by(&:position)
      by_code = game.symbols.index_by(&:code)

      disagreed = []
      walked = 0
      ranges = strips.map { |strip| (0...strip.symbols.length).to_a }

      ranges[0].product(*ranges[1..]) do |stops|
        columns = strips.each_with_index.map do |strip, reel|
          codes = strip.symbols
          Array.new(game.row_count) { |offset| by_code[codes[(stops[reel] + offset) % codes.length]] }
        end

        expected = mechanic.wins(ReelWindow.new(game, columns), entries).sum(&:payout)
        actual = table.payout_at(stops)
        walked += 1

        disagreed << [ stops, expected, actual ] unless actual == expected
      end

      assert_equal outcomes, walked, "the walk did not cover the space it claims to"
      assert_empty disagreed.first(3),
        "#{disagreed.size} of #{walked} outcomes disagree, shown as [stops, mechanic, table]"
    end

    # Three reels of three rows, four stops each: 64 outcomes, and every rule Red White
    # & Blue leaves untouched. A x2 combination stops short of the third reel, a wild
    # lands on every strip, and one of the two paylines bends off the centre row.
    def mixed_variation
      game = users(:one).games.create!(name: "Mixed", reel_count: 3, row_count: 3)
      codes = %w[ WD A K Q ]
      symbols = codes.each_with_index.to_h do |code, position|
        [ code, game.symbols.create!(code: code, name: code, position: position + 1, wild: code == "WD") ]
      end

      game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])
      game.paylines.create!(position: 2, rows: [ 1, 0, -1 ])

      variation = game.variations.first
      3.times { |reel| variation.reel_strips.create!(position: reel + 1, symbols: codes) }

      { %w[ A A ] => 5, %w[ A A A ] => 25, %w[ K K K ] => 10, %w[ Q Q ] => 2 }.each do |sequence, payout|
        entry = variation.paytable_entries.new(payout: payout)
        sequence.each_with_index { |code, index| entry.matchers.build(position: index + 1, game_symbol: symbols[code]) }
        entry.save!
      end

      variation
    end
end
