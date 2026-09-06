require "test_helper"

# A run that samples rather than evaluates. The same lifecycle as any other calculation —
# it queues, it can be watched, it can fail — differing only in how it arrives at a
# figure and in what it has to record about having done so.
class SimulationRunTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Loose enough to settle in a few hundred thousand spins. Red White & Blue is far more
  # volatile than its return suggests, and a tighter request here would spend the whole
  # test suite's budget proving something a looser one proves just as well.
  POINTS = 4.0
  CEILING = 2_000_000

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "a sampled run produces a sampled figure and finishes" do
    calculation = run_sampling

    assert_predicate calculation, :done?
    assert_equal Rtp::SAMPLED.to_s, calculation.computed_by
    assert_not_predicate calculation.rtp_figure, :exact?
    assert_equal calculation.spins, calculation.rtp_figure.spins
  end

  test "the figure it records carries the interval and what was seen" do
    figure = run_sampling.rtp_figure

    assert_equal 95, figure.to_result.interval.confidence
    assert_operator figure.to_result.interval.points, :<=, POINTS
    assert_equal "R7 W7 B7", figure.coverage.first["combination"]
  end

  test "a run records why it stopped" do
    assert_equal "precision", run_sampling.stopped_because
  end

  test "a run that cannot reach the precision stops at its ceiling and says so" do
    calculation = run_sampling(points: 0.01, ceiling: 200_000)

    assert_equal "ceiling", calculation.stopped_because
    assert_equal 200_000, calculation.spins
  end

  # An unreproducible figure cannot be investigated, and a figure somebody disputes is
  # the case this exists to serve.
  test "the seed is recorded, and reproduces the figure" do
    first = run_sampling
    second = run_sampling(seed: first.seed)

    assert_equal first.seed, second.seed
    assert_equal first.rtp_figure.value, second.rtp_figure.value
  end

  test "a run given no seed invents one and keeps it" do
    seeds = 2.times.map { run_sampling(seed: nil).seed }

    assert_none_nil seeds
    assert_not_equal seeds.first, seeds.second,
      "inventing the same seed every time would make every run identical"
  end

  test "an incomplete description fails the run rather than raising" do
    empty = @game.variations.create!(number: 2)

    calculation = perform_enqueued_jobs { simulate(empty) }.reload

    assert_predicate calculation, :failed?
    assert_nil calculation.rtp_figure
    assert_match(/no reel strips/, calculation.failure)
  end

  test "an exact run still records nothing about sampling" do
    calculation = perform_enqueued_jobs { Calculation.start(@variation) }.reload

    assert_predicate calculation, :done?
    assert_nil calculation.seed
    assert_nil calculation.stopped_because
    assert_predicate calculation.rtp_figure, :exact?
  end

  private
    def assert_none_nil(values) = assert_empty values.select(&:nil?), "every run must keep a seed"

    def run_sampling(points: POINTS, ceiling: CEILING, seed: :unset)
      perform_enqueued_jobs { simulate(@variation, points: points, ceiling: ceiling, seed: seed) }.reload
    end

    def simulate(variation, points: POINTS, ceiling: CEILING, seed: :unset)
      precision = Rtp::Precision.new(points: points, confidence: 95, ceiling: ceiling)

      if seed == :unset
        Calculation.simulate(variation, precision: precision)
      else
        Calculation.simulate(variation, precision: precision, seed: seed)
      end
    end
end
