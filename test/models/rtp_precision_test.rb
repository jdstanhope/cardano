require "test_helper"

# Asking for a figure by how accurate it needs to be, rather than by how long to spend.
class RtpPrecisionTest < ActiveSupport::TestCase
  SEED = 20_260_906

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "a run that reaches the precision asked for stops and says so" do
    simulation = simulate
    result = simulation.run_to(precision(points: 3.5, ceiling: 100_000_000))

    assert_equal :precision, simulation.stopped_because
    assert_operator result.interval.points, :<=, 3.5
    assert_operator simulation.spins, :<, 100_000_000, "it stopped early, so not at the ceiling"
  end

  test "a run that cannot reach it stops at the ceiling and says that instead" do
    simulation = simulate
    result = simulation.run_to(precision(points: 0.001, ceiling: 180_000))

    assert_equal :ceiling, simulation.stopped_because
    assert_equal 180_000, simulation.spins,
      "180,000 is not a whole number of batches, so a run that ignored the ceiling " \
      "between checks would sail past it to 200,000"
    assert_operator result.interval.points, :>, 0.001,
      "reaching the ceiling short of the precision is a result, and the interval is what it is"
  end

  # An interval taken from a handful of spins can be narrow by luck, and a rule that
  # believed it would end almost every run immediately.
  test "precision cannot end a run before the floor, however narrow the interval looks" do
    simulation = simulate
    simulation.run_to(precision(points: 100.0, ceiling: 100_000_000))

    assert_equal :precision, simulation.stopped_because
    assert_equal Rtp::Precision::FLOOR, simulation.spins,
      "a precision that trivial would have stopped at the first check without a floor"
  end

  # Both reasons can arrive on the same batch. Which is reported is a choice, and the
  # choice is to report what was found rather than the limit it happened to coincide with.
  test "a run reaching its precision and its ceiling at once reports the precision" do
    simulation = simulate
    simulation.run_to(precision(points: 100.0, ceiling: Rtp::Precision::FLOOR))

    assert_equal :precision, simulation.stopped_because
    assert_equal Rtp::Precision::FLOOR, simulation.spins
  end

  test "a figure arrived at this way is still the right figure" do
    exact = @variation.rtp
    simulation = simulate
    result = simulation.run_to(precision(points: 1.5, ceiling: 100_000_000))

    assert_operator (result.value - exact.value).abs, :<=, result.interval.half_width,
      "sampled #{result.to_percentage(4)} against an exact #{exact.to_percentage(4)} " \
      "after #{simulation.spins} spins, interval #{result.interval}"
  end

  test "the confidence asked for is the confidence reported" do
    simulation = simulate
    result = simulation.run_to(precision(points: 3.5, confidence: 99, ceiling: 100_000_000))

    assert_equal 99, result.interval.confidence
  end

  test "nothing has stopped before a run has begun" do
    assert_nil simulate.stopped_because
  end

  private
    def simulate = Rtp::Simulation.new(@variation, seed: SEED)

    def precision(points:, ceiling:, confidence: 95)
      Rtp::Precision.new(points: points, confidence: confidence, ceiling: ceiling)
    end
end
