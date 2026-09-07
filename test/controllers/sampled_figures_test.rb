require "test_helper"

# How a sampled figure reads on the page. The one thing the design forbids is showing it
# the way an exact one is shown: a bare percentage says the number is the answer, when
# what was found is a range and how sure the run is of it.
class SampledFiguresTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SEED = 20_260_906

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  def rtp_section = css_select("[data-rtp]").first.text

  test "a sampled figure carries its interval beside the figure itself" do
    sample

    get game_variation_url(@game, @variation)

    assert_response :success
    assert_select "[data-interval]", /±\d+\.\d\d/
  end

  test "it says it was sampled, over how many spins, and to what confidence" do
    sample

    get game_variation_url(@game, @variation)

    assert_match(/Sampled/, rtp_section)
    assert_match(/at 95%/, rtp_section)
    assert_match(/20,000 spins/, rtp_section)
  end

  test "it shows how often each combination landed, largest payout first" do
    sample

    get game_variation_url(@game, @variation)
    seen = css_select("[data-coverage] [data-combination]").map { |row| row["data-combination"] }

    assert_equal "R7 W7 B7", seen.first
    assert_equal @variation.paytable_entries.count, seen.length
  end

  # The whole point of showing coverage is the reader noticing the line that undermines
  # the interval above it, without having to read all fifteen.
  test "a combination barely seen is marked, and a well sampled one is not" do
    sample

    get game_variation_url(@game, @variation)

    assert_select "[data-combination='R7 W7 B7'][data-thin]", 1,
      "one spin in 262,144 pays this, so 20,000 spins cannot have established it"
    assert_select "[data-combination='-- -- --'][data-thin]", 0,
      "blanks land constantly and nothing about them is in doubt"
  end

  # A twenty thousand spin sample of a machine with a 2400 combination is nowhere near
  # settled, and the page must not turn where it happened to land into a verdict on the
  # game. The interval here spans some eighteen points either side of the band.
  test "a figure too uncertain to judge against the band says so, rather than missing it" do
    sample

    get game_variation_url(@game, @variation)

    assert_select "[data-standing='unsettled']", 1
    assert_select "[data-standing='below']", 0
    assert_match(/the interval reaches past it/, rtp_section)
  end

  test "an exact figure is still judged against the band as a point" do
    perform_enqueued_jobs { get game_variation_url(@game, @variation) }

    get game_variation_url(@game, @variation)

    assert_select "[data-standing='inside']", 1
  end

  test "a run says why it stopped" do
    sample

    get game_variation_url(@game, @variation)

    assert_match(/ceiling/, css_select("[data-calculation]").first.text)
  end

  # An exact figure is not out by anything, and dressing it in the language of estimates
  # would give away the thing evaluating every outcome was for.
  test "an exact figure shows no interval, no spins and no coverage" do
    perform_enqueued_jobs { get game_variation_url(@game, @variation) }

    get game_variation_url(@game, @variation)

    assert_match(/86\.58%/, rtp_section)
    assert_match(/Exact/, rtp_section)
    assert_select "[data-interval]", 0
    assert_select "[data-coverage]", 0
  end

  private
    # A ceiling rather than a precision, so the run is short and its length is a fact the
    # test states rather than one the variance decides.
    def sample
      precision = Rtp::Precision.new(points: 0.01, confidence: 95, ceiling: 20_000)

      perform_enqueued_jobs { Calculation.simulate(@variation, precision: precision, seed: SEED) }
    end
end
