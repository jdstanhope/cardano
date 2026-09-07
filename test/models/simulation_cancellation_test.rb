require "test_helper"

# Stopping a run that is already going.
#
# Exact evaluation takes seconds and cancelling it mid-way loses nothing, because there
# is no partial answer to lose. A simulation is minutes to hours and does have one, so
# stopping it is both something a person will actually do and something that should leave
# them with what it found.
class SimulationCancellationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  SEED = 20_260_906
  CEILING = 100_000_000

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "a run stops when it is interrupted, and says that is why" do
    simulation = Rtp::Simulation.new(@variation, seed: SEED)
    simulation.run_to(precision, interrupted: -> { true })

    assert_equal :cancelled, simulation.stopped_because
    assert_equal Rtp::Precision::BATCH, simulation.spins,
      "nothing can interrupt a run before it has played, so it stops one batch in"
  end

  # A run that got the accuracy it was asked for has finished. Reporting the interruption
  # would describe how it ended rather than what it achieved.
  test "reaching the precision on the same batch as an interruption reports the precision" do
    simulation = Rtp::Simulation.new(@variation, seed: SEED)
    asked = 0
    simulation.run_to(precision(points: 100.0), interrupted: -> { (asked += 1) > 1 })

    assert_equal :precision, simulation.stopped_because
    assert_equal Rtp::Precision::FLOOR, simulation.spins,
      "the interruption and the precision have to actually coincide for this to mean anything"
  end

  test "a run nobody interrupts is unaffected" do
    simulation = Rtp::Simulation.new(@variation, seed: SEED)
    simulation.run_to(precision(points: 100.0), interrupted: -> { false })

    assert_equal :precision, simulation.stopped_because
  end

  # The trap. Rails installs a query cache around job execution, so a repeated read of
  # the same row is answered from memory: ["db", "CACHED", "CACHED"]. A poll that did not
  # read past it would see `running` once and then answer `running` for the rest of the
  # run, never noticing the cancellation and leaving nothing in the logs to say why.
  test "the poll for cancellation reads past the query cache a job runs inside" do
    calculation = Calculation.simulate(@variation, precision: precision, seed: SEED)
    from_cache = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| from_cache << !!payload[:cached] }

    ActiveRecord::Base.cache { 3.times { calculation.send(:cancelled_elsewhere?) } }
    ActiveSupport::Notifications.unsubscribe(subscriber)

    assert_equal [ false, false, false ], from_cache,
      "a cached read answers with the state the run started with, for ever"
  end

  # Stopped on the second poll rather than the first, which pins that the run asks again
  # between batches instead of once at the start. Two batches in, and no more.
  test "cancelling a running simulation stops it promptly and keeps the figure it reached" do
    calculation = Calculation.simulate(@variation, precision: precision, seed: SEED)
    asked = 0
    calculation.define_singleton_method(:cancelled_elsewhere?) { (asked += 1) >= 2 }

    calculation.perform
    calculation.reload

    assert_predicate calculation, :cancelled?
    assert_equal "cancelled", calculation.stopped_because
    assert_equal 2, asked, "it has to keep asking, not ask once"
    assert_equal 2 * Rtp::Precision::BATCH, calculation.spins
    assert_equal calculation.spins, calculation.rtp_figure.spins
  end

  test "a run cancelled before it starts records nothing at all" do
    calculation = Calculation.simulate(@variation, precision: precision, seed: SEED)
    calculation.cancel!

    assert_no_difference -> { @variation.rtp_figures.count } do
      calculation.perform
    end

    assert_nil calculation.reload.rtp_figure
    assert_nil calculation.spins
  end

  test "a run nobody stops still finishes as done" do
    calculation = perform_enqueued_jobs { Calculation.simulate(@variation, precision: precision(points: 100.0), seed: SEED) }

    assert_predicate calculation.reload, :done?
    assert_equal "precision", calculation.stopped_because
  end

  private
    def precision(points: 0.01) = Rtp::Precision.new(points: points, confidence: 95, ceiling: CEILING)
end
