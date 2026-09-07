require "test_helper"

# Whether a figure lands in the band a variation is aiming for.
#
# This is the answer a designer acts on — it is "is this variation shippable" — so it has
# to mean the same thing however the figure was arrived at. For an exact figure that is a
# point against a range. For a sampled one it cannot be: the figure is a range too, and
# comparing only its midpoint reports where an uncertain sample happened to land as
# though it were a property of the game.
class TargetBandTest < ActiveSupport::TestCase
  MINIMUM = 8_600
  MAXIMUM = 8_700

  test "an exact figure is judged as a point, because that is what it is" do
    assert_equal :inside, exact(86.50).against(MINIMUM, MAXIMUM)
    assert_equal :below, exact(85.00).against(MINIMUM, MAXIMUM)
    assert_equal :above, exact(88.00).against(MINIMUM, MAXIMUM)
  end

  test "an exact figure exactly on an edge is inside, as it was before" do
    assert_equal :inside, exact(86.00).against(MINIMUM, MAXIMUM)
    assert_equal :inside, exact(87.00).against(MINIMUM, MAXIMUM)
  end

  # The case that prompted this. 81.27% +/-8.73 spans 72.54% to 90.00%, which contains the
  # band whole and the true figure with it. Calling that "below band" sends somebody to
  # re-cut reel strips that were fine.
  test "a sampled figure whose interval straddles the band has not settled it" do
    assert_equal :unsettled, sampled(81.27, 8.73).against(MINIMUM, MAXIMUM)
  end

  test "a sampled figure straddling one edge has not settled it either" do
    assert_equal :unsettled, sampled(86.50, 0.60).against(MINIMUM, MAXIMUM)
    assert_equal :unsettled, sampled(86.90, 0.60).against(MINIMUM, MAXIMUM)
  end

  # A tight enough interval settles the question, and then it is answered as usual.
  test "a sampled figure clear of the band is judged against it" do
    assert_equal :below, sampled(81.27, 0.10).against(MINIMUM, MAXIMUM)
    assert_equal :above, sampled(88.00, 0.10).against(MINIMUM, MAXIMUM)
  end

  test "a sampled figure whose whole interval sits inside the band is in it" do
    assert_equal :inside, sampled(86.50, 0.10).against(MINIMUM, MAXIMUM)
  end

  test "a variation with no band gets no verdict, sampled or not" do
    assert_nil exact(86.50).against(nil, nil)
    assert_nil sampled(86.50, 0.10).against(nil, nil)
  end

  private
    def exact(percentage) = Rtp::Result.new(value: basis(percentage), method: Rtp::EXACT)

    def sampled(percentage, points)
      Rtp::Result.new(value: basis(percentage), method: Rtp::SAMPLED,
                      interval: Rtp::Interval.new(half_width: points / 100.0, confidence: 95))
    end

    def basis(percentage) = Rational((percentage * 100).round, 10_000)
end
