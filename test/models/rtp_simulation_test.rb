require "test_helper"

# Sampling Red White & Blue, whose exact return is known to the last figure.
#
# That is what makes this worth testing at all: a sampler can only be shown correct
# against something independently known, and the published machine is the one game here
# whose answer is not also produced by the code under test.
class RtpSimulationTest < ActiveSupport::TestCase
  # Fixed, and not an implementation detail. "Lands within its stated interval" is a
  # probabilistic claim that fails one run in twenty at 95%, so a random seed would make
  # this go red every few weeks for no reason — and a test that cries wolf gets ignored,
  # which is worth less than no test at all.
  SEED = 20_260_906

  # Enough that the interval means something. Red White & Blue is far more volatile than
  # its return suggests, because one combination in it pays 2400 and dominates the
  # spread: at 300,000 spins the interval is still +/-3.2 points.
  SPINS = 1_200_000

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    @exact = @variation.rtp
  end

  test "a sampled figure lands within its own stated interval of the exact one" do
    result = simulate(spins: SPINS)
    missed = (result.value - @exact.value).abs

    assert_operator result.interval.points, :<, 2.0,
      "an interval wide enough to contain anything would contain the right answer too"
    assert_operator missed, :<=, result.interval.half_width,
      "sampled #{result.to_percentage(4)} against an exact #{@exact.to_percentage(4)}, " \
      "off by #{'%.4f' % (missed * 100)} points with an interval of #{result.interval}"
  end

  # The interval is only worth reporting if it is the standard error and not merely
  # something interval-shaped. Quadrupling the spins has to halve it, and nothing that
  # gets the arithmetic wrong will do that by accident.
  test "the interval narrows as the square root of the spins" do
    wide = simulate(spins: SPINS / 4).interval.points
    narrow = simulate(spins: SPINS).interval.points

    assert_in_delta 2.0, wide / narrow, 0.2,
      "#{'%.2f' % wide} points over four times as many spins became #{'%.2f' % narrow}"
  end

  test "the figure is exact even though it was sampled" do
    spins = 5_000
    scaled = simulate(spins: spins).value * spins * SpinTable.for(@variation).stake_units

    assert_equal 1, scaled.denominator,
      "the estimate is a whole payout over a whole count of spins, and rounding it into " \
      "a float would give away the one thing sampling can still be exact about"
  end

  test "a sampled figure never passes for an exact one" do
    result = simulate(spins: 1_000)

    assert_not_predicate result, :exact?
    assert_equal Rtp::SAMPLED, result.method
    assert_predicate @exact, :exact?, "the exact route must still say so"
  end

  test "a single spin refuses to claim any accuracy at all" do
    assert_predicate simulate(spins: 1).interval.half_width, :infinite?
  end

  test "the same seed reproduces the figure exactly" do
    first = simulate(spins: 5_000)
    second = simulate(spins: 5_000)
    other = Rtp::Simulation.new(@variation, seed: SEED + 1).run(spins: 5_000)

    assert_equal first.value, second.value
    assert_not_equal first.value, other.value,
      "every seed agreeing would mean the seed was not being used"
  end

  # Red White & Blue bets one unit on one payline, so its stake is 1 and every division
  # by it is invisible — a figure that forgot to divide would be identical. A ways game
  # stakes a unit per way: eight here, and 243 on an ordinary five reel game, which is
  # the factor a missing divisor would be wrong by.
  test "a game staking more than one unit a spin divides the figure and the interval by it" do
    variation = eight_way_variation
    exact = Rtp.new(variation).call
    result = Rtp::Simulation.new(variation, seed: SEED).run(spins: SPINS)

    assert_equal 8, SpinTable.for(variation).stake_units, "the game under test has to actually stake eight"
    assert_operator result.interval.points, :<, 1.0, "an undivided interval would be eight times this wide"
    assert_operator (result.value - exact.value).abs, :<=, result.interval.half_width,
      "sampled #{result.to_percentage(4)} against an exact #{exact.to_percentage(4)}, " \
      "interval #{result.interval}"
  end

  private
    def simulate(spins:) = Rtp::Simulation.new(@variation, seed: SEED).run(spins: spins)

    def eight_way_variation
      game = users(:one).games.create!(name: "Eight Ways", reel_count: 3, row_count: 2, win_mechanic: "ways")
      codes = %w[ A K Q ]
      symbols = codes.each_with_index.to_h do |code, position|
        [ code, game.symbols.create!(code: code, name: code, position: position + 1) ]
      end

      variation = game.variations.first
      3.times { |reel| variation.reel_strips.create!(position: reel + 1, symbols: codes) }

      { %w[ A A A ] => 20, %w[ K K K ] => 10 }.each do |sequence, payout|
        entry = variation.paytable_entries.new(payout: payout)
        sequence.each_with_index { |code, index| entry.matchers.build(position: index + 1, game_symbol: symbols[code]) }
        entry.save!
      end

      variation
    end
end
