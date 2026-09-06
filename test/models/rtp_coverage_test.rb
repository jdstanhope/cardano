require "test_helper"

# What a sampled figure has actually seen, as opposed to what it claims to know.
#
# The interval is computed from the spread of what landed. Before a rare combination has
# landed at all, that spread is drawn from a distribution missing its tail, and the
# interval is confident about an accuracy it has not earned. No arithmetic on the sample
# can notice this, so the run says how often each combination fell and lets the reader
# decide.
class RtpCoverageTest < ActiveSupport::TestCase
  SEED = 20_260_906
  SPINS = 200_000

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  # The tally has to be checked against something that is not itself. Both the payout and
  # the tally index come off the same winning bit, so totals agreeing with the coverage
  # proves only that the two agree with each other. Asking the mechanic which combination
  # won, on every outcome there is, is the check that does not fold back on itself.
  test "coverage counts the combinations the mechanic says won, on every outcome" do
    assert_coverage_matches_the_mechanic lines_variation, outcomes: 64
  end

  test "coverage counts them on a ways game too, where several pay at once" do
    assert_coverage_matches_the_mechanic ways_variation, outcomes: 64
  end

  # Cheaper and at a scale the walks cannot reach: every winning line pays exactly its
  # combination's payout, so over 200,000 spins the total has to be the sum of hits times
  # payout. It would catch a tally counting twice, which agreeing with the mechanic on a
  # 64 outcome game might not.
  test "the tally accounts for every unit the run paid out" do
    simulation = Rtp::Simulation.new(@variation, seed: SEED)
    result = simulation.run(spins: SPINS)

    paid = (result.value * SPINS * SpinTable.for(@variation).stake_units).to_i
    tallied = simulation.coverage.sum { |line| line.hits * line.payout }

    assert_equal paid, tallied
    assert_operator paid, :>, 0, "a run that paid nothing would satisfy this while proving nothing"
  end

  test "a combination that cannot have landed is reported as never landing" do
    simulation = Rtp::Simulation.new(@variation, seed: SEED)
    simulation.run(spins: 200)

    assert_equal 0, simulation.coverage.find { |line| line.payout == 2_400 }.hits,
      "one spin in 262,144 pays this, so two hundred spins finding one would be remarkable"
  end

  test "a rarer combination is seen less often than a common one" do
    simulation = Rtp::Simulation.new(@variation, seed: SEED)
    simulation.run(spins: SPINS)

    by_payout = simulation.coverage.index_by(&:payout)

    assert_operator by_payout[1_199].hits, :<, by_payout[1].hits, "three red sevens against three blanks"
  end

  test "coverage names the combination, not just its payout" do
    simulation = Rtp::Simulation.new(@variation, seed: SEED)
    simulation.run(spins: 1_000)

    assert_equal "R7 W7 B7", simulation.coverage.find { |line| line.payout == 2_400 }.combination
  end

  # On a lines game the compiled order is already by payout, so ordering there would hold
  # whether anything sorted or not. This paytable is written deliberately out of order.
  test "the combinations most likely to be undersampled read first" do
    simulation = Rtp::Simulation.new(ways_variation, seed: SEED)
    simulation.run(spins: 1_000)

    payouts = simulation.coverage.map(&:payout)

    assert_equal [ 30, 25, 10 ], payouts, "written 10, 30, 25 and reported largest first"
  end

  private
    def assert_coverage_matches_the_mechanic(variation, outcomes:)
      game = variation.game
      table = SpinTable.for(variation)
      mechanic = WinMechanic.for(game)
      entries = variation.paytable
      strips = variation.reel_strips.sort_by(&:position)
      by_code = game.symbols.index_by(&:code)

      expected = Hash.new(0)
      walked = 0
      ranges = strips.map { |strip| (0...strip.symbols.length).to_a }

      ranges[0].product(*ranges[1..]) do |stops|
        columns = strips.each_with_index.map do |strip, reel|
          codes = strip.symbols
          Array.new(game.row_count) { |offset| by_code[codes[(stops[reel] + offset) % codes.length]] }
        end

        mechanic.wins(ReelWindow.new(game, columns), entries).each { |win| expected[win.entry.sequence.join(" ")] += 1 }
        table.payout_at(stops)
        walked += 1
      end

      tallied = table.coverage.reject { |seen| seen.hits.zero? }.to_h { |seen| [ seen.combination, seen.hits ] }

      assert_equal outcomes, walked, "the walk did not cover the space it claims to"
      assert_operator expected.values.sum, :>, 0, "a space where nothing ever wins would prove nothing"
      assert_equal expected.to_h, tallied
    end

    # A x2 pays more than A x3 so the two share a family and the shorter one sometimes
    # wins it, which is the only way "the best in a family" is exercised at all. Written
    # out of payout order so the reported ordering has something to do.
    PAYTABLE = { %w[ K K K ] => 10, %w[ A A ] => 30, %w[ A A A ] => 25 }.freeze

    def lines_variation
      game = users(:one).games.create!(name: "Small Lines", reel_count: 3, row_count: 1)
      game.paylines.create!(position: 1, rows: [ 0, 0, 0 ])

      build(game)
    end

    def ways_variation
      build(users(:one).games.create!(name: "Small Ways", reel_count: 3, row_count: 2, win_mechanic: "ways"))
    end

    # Two A's on the strip, so a two row window can show a reel offering *two* matching
    # positions. Without that the arrangements never exceed one, A x3 can never out-pay
    # A x2, and the "best in the family" choice is never actually made.
    STRIP = %w[ A A K Q ].freeze

    def build(game)
      codes = %w[ A K Q ]
      symbols = codes.each_with_index.to_h do |code, position|
        [ code, game.symbols.create!(code: code, name: code, position: position + 1) ]
      end

      variation = game.variations.first
      3.times { |reel| variation.reel_strips.create!(position: reel + 1, symbols: STRIP) }

      PAYTABLE.each do |sequence, payout|
        entry = variation.paytable_entries.new(payout: payout)
        sequence.each_with_index { |code, index| entry.matchers.build(position: index + 1, game_symbol: symbols[code]) }
        entry.save!
      end

      variation
    end
end
