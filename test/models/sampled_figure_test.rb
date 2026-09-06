require "test_helper"

# Keeping a figure that was sampled, which is a different kind of record from one that
# was evaluated: it might be out by something, and how far it might be out is part of
# what was found rather than a footnote to it.
class SampledFigureTest < ActiveSupport::TestCase
  SEED = 20_260_906

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "a sampled figure keeps its interval, and gives it back" do
    figure = record(spins: 20_000)
    result = figure.to_result

    assert_not_predicate figure, :exact?
    assert_equal Rtp::SAMPLED, result.method
    assert_in_delta @sampled.interval.half_width, result.interval.half_width, 1e-9
    assert_equal 95, result.interval.confidence
  end

  test "a sampled figure keeps what it actually saw" do
    figure = record(spins: 20_000)

    assert_equal 20_000, figure.spins
    assert_operator figure.coverage.sum { |line| line["hits"] }, :>, 0
    assert_equal "R7 W7 B7", figure.coverage.first["combination"],
      "stored largest payout first, so the tail reads at the top"
  end

  # The reason deduplication exists is that an unchanged configuration evaluates to the
  # same figure twice, and a history full of identical rows is unreadable. Sampling
  # breaks that premise: two runs of one configuration legitimately differ, and dropping
  # the second would show one figure where two runs happened.
  test "two sampled runs of one configuration both record" do
    assert_difference -> { @variation.rtp_figures.count }, 2 do
      record(spins: 5_000, seed: SEED)
      record(spins: 5_000, seed: SEED + 1)
    end
  end

  # The other direction of the same rule. An exact figure on hand does not answer a
  # question about sampling, and discarding the run would lose the interval and the
  # coverage that were the reason for running it.
  test "a sampled run after an exact figure still records" do
    @variation.record_rtp

    assert_difference -> { @variation.rtp_figures.count }, 1 do
      record(spins: 5_000)
    end
  end

  test "two exact runs of one configuration still record once" do
    assert_difference -> { @variation.rtp_figures.count }, 1 do
      3.times { @variation.reload.record_rtp }
    end
  end

  # The fingerprints match, so the old rule would hand back the estimate and throw the
  # exact figure away — replacing the best answer available with a worse one.
  test "an exact figure is never discarded in favour of a stored sampled one" do
    record(spins: 5_000)

    assert_difference -> { @variation.rtp_figures.count }, 1 do
      @variation.reload.record_rtp
    end

    assert_predicate @variation.reload.latest_rtp_figure, :exact?
  end

  test "an exact figure carries no interval, because it is not out by anything" do
    @variation.record_rtp
    figure = @variation.latest_rtp_figure

    assert_nil figure.half_width
    assert_nil figure.spins
    assert_nil figure.to_result.interval
  end

  private
    def record(spins:, seed: SEED)
      simulation = Rtp::Simulation.new(@variation, seed: seed)
      @sampled = simulation.run(spins: spins)

      RtpFigure.record(@variation, @sampled, spins: simulation.spins, coverage: simulation.coverage)
    end
end
