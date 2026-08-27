require "test_helper"

class RtpFigureTest < ActiveSupport::TestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
  end

  test "computing a figure records it" do
    assert_difference -> { @variation.rtp_figures.count }, 1 do
      @variation.record_rtp
    end

    figure = @variation.latest_rtp_figure
    assert_equal @variation.rtp.value, figure.value
    assert_predicate figure, :exact?
    assert_equal "86.5761%", figure.to_percentage(4)
  end

  # The figure is kept as the fraction it was computed as. Rounding it on the way in
  # would give up the exactness that evaluating every outcome was for, and would make
  # two genuinely different figures compare as equal.
  test "the figure survives the round trip exactly" do
    @variation.record_rtp

    assert_equal @variation.rtp.value, @variation.latest_rtp_figure.value
    assert_kind_of Rational, @variation.latest_rtp_figure.value
  end

  test "recomputing an unchanged variation records nothing further" do
    @variation.record_rtp

    assert_no_difference -> { @variation.rtp_figures.count } do
      3.times { @variation.reload.record_rtp }
    end
  end

  test "a change records a new figure alongside the old one" do
    @variation.record_rtp
    before = @variation.latest_rtp_figure

    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)
    @variation.reload.record_rtp

    assert_equal 2, @variation.rtp_figures.count
    assert_not_equal before.value, @variation.latest_rtp_figure.value
    assert_equal before, @variation.rtp_figures.newest_first.last
  end

  test "an incomplete description records nothing" do
    empty = @game.variations.create!(number: 2)

    assert_no_difference -> { RtpFigure.count } do
      result = empty.record_rtp
      assert_not_predicate result, :complete?
    end
  end

  test "the difference from an earlier figure is in percentage points" do
    @variation.record_rtp
    before = @variation.latest_rtp_figure

    @variation.paytable_entries.find_by(payout: 1199).update!(payout: 2398)
    @variation.reload.record_rtp

    points = @variation.latest_rtp_figure.points_from(before)
    assert_operator points, :>, 0
    assert_in_delta (@variation.rtp.value - before.value) * 100, points, 0.0001
  end

  test "figures go when the variation does" do
    @variation.record_rtp

    assert_difference -> { RtpFigure.count }, -1 do
      @variation.destroy!
    end
  end
end
