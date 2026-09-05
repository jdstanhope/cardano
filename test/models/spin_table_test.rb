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

  # Ways selects differently enough from lines to be worth its own walk: every
  # combination is measured, several pay at once, and each pays as many times as the
  # arrangements allow.
  test "the compiled table agrees on a ways game, where a combination pays many times" do
    assert_agrees_with_the_mechanic ways_variation, outcomes: 64
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
    # lands on every strip, a combination names a group, and one of the two paylines
    # bends off the centre row.
    def mixed_variation
      game = users(:one).games.create!(name: "Mixed", reel_count: 3, row_count: 3)
      game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])
      game.paylines.create!(position: 2, rows: [ 1, 0, -1 ])

      build_variation(game, { %w[ A A ] => 5, %w[ A A A ] => 25, %w[ K K K ] => 10,
                              %w[ Q Q ] => 2, %w[ Royals Royals Royals ] => 3 })
    end

    # Two rows, so a reel can offer a combination more than one matching position and the
    # arrangements multiply above one.
    #
    # A x2 pays more than A x3 deliberately, which is unusual for a real paytable and the
    # entire point. Ways takes the best *paying* combination in a family, not the longest,
    # and while a longer combination always out-pays a shorter one the two rules cannot be
    # told apart. Here A x2 wins when the third reel offers one match and loses when it
    # offers two, so both branches occur inside the 64 outcomes.
    def ways_variation
      game = users(:one).games.create!(name: "Ways", reel_count: 3, row_count: 2, win_mechanic: "ways")

      build_variation(game, { %w[ A A ] => 30, %w[ A A A ] => 25, %w[ K K K ] => 10,
                              %w[ Royals Royals Royals ] => 3 })
    end

    # Four symbols, one of them wild, one group over two of them, and a strip per reel
    # holding each symbol once — so every reel can show anything and the space stays at
    # four stops.
    def build_variation(game, table)
      codes = %w[ WD A K Q ]
      named = codes.each_with_index.to_h do |code, position|
        [ code, game.symbols.create!(code: code, name: code, position: position + 1, wild: code == "WD") ]
      end
      named["Royals"] = game.symbol_groups.create!(name: "Royals", position: 1)
      named["Royals"].game_symbols << [ named["A"], named["K"] ]

      variation = game.variations.first
      game.reel_count.times { |reel| variation.reel_strips.create!(position: reel + 1, symbols: codes) }

      table.each do |sequence, payout|
        entry = variation.paytable_entries.new(payout: payout)
        sequence.each_with_index do |label, index|
          thing = named.fetch(label)
          entry.matchers.build(position: index + 1,
                               thing.is_a?(SymbolGroup) ? :symbol_group : :game_symbol => thing)
        end
        entry.save!
      end

      variation
    end
end
