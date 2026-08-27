require "test_helper"

class CalculationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "a run produces a figure and finishes" do
    calculation = perform_enqueued_jobs { Calculation.start(@variation) }.reload

    assert_predicate calculation, :done?
    assert_equal Rtp::EXACT.to_s, calculation.computed_by
    assert_equal "86.5761%", calculation.rtp_figure.to_percentage(4)
    assert calculation.finished_at
  end

  test "it is queued before it runs" do
    calculation = Calculation.start(@variation)

    assert_predicate calculation, :in_flight?
    assert_equal Calculation::QUEUED, calculation.state
    assert_nil calculation.rtp_figure
  end

  test "an incomplete description fails the run rather than recording a figure" do
    empty = @game.variations.create!(number: 2)

    calculation = perform_enqueued_jobs { Calculation.start(empty) }.reload

    assert_predicate calculation, :failed?
    assert_nil calculation.rtp_figure
    assert_match(/no reel strips/, calculation.failure)
    assert_equal 0, empty.rtp_figures.count
  end

  # A run that blew up is a result to look at, not a job to retry forever.
  test "a run that raises is recorded as failed rather than escaping" do
    calculation = Calculation.start(@variation)

    stubbing_rtp_to_raise do
      assert_nothing_raised { calculation.perform }
    end

    assert_predicate calculation.reload, :failed?
    assert_match(/deliberate/, calculation.failure)
  end

  test "a cancelled run does not go on to compute anything" do
    calculation = Calculation.start(@variation)
    calculation.cancel!

    assert_no_difference -> { RtpFigure.count } do
      calculation.perform
    end

    assert_predicate calculation.reload, :cancelled?
  end

  # A run started before an edit answers a question about a description that no longer
  # exists. It is not wrong, but presenting it as current would be.
  test "a run knows whether it still describes the variation" do
    calculation = perform_enqueued_jobs { Calculation.start(@variation) }.reload
    assert_predicate calculation, :describes_the_variation_now?

    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)

    assert_not_predicate calculation.reload, :describes_the_variation_now?
  end

  test "runs go when the variation does" do
    Calculation.start(@variation)

    assert_difference -> { Calculation.count }, -1 do
      @variation.destroy!
    end
  end

  private
    # Minitest 6 no longer bundles a mock, and this needs one method to misbehave for
    # one call. Swapped and restored whatever happens, so nothing leaks into the rest
    # of the suite.
    def stubbing_rtp_to_raise
      Variation.send(:alias_method, :rtp_without_stub, :rtp)
      Variation.send(:define_method, :rtp) { raise "deliberate" }
      yield
    ensure
      Variation.send(:remove_method, :rtp)
      Variation.send(:alias_method, :rtp, :rtp_without_stub)
      Variation.send(:remove_method, :rtp_without_stub)
    end
end
