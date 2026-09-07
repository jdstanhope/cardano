require "application_system_test_case"

class SampledFiguresTest < ApplicationSystemTestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_through_the_form(users(:one))
  end

  # A ceiling of twenty thousand spins on a machine where one combination pays 2400: the
  # figure is nowhere near settled, and the page has to say so rather than presenting the
  # number it happens to have arrived at.
  test "a sampled figure shows what it might be out by, and what it barely saw" do
    sample

    visit game_variation_path(@game, @variation)

    assert_selector "[data-interval]"
    assert_text "Sampled"
    assert_text "20,000 spins"
    assert_text "stopped on ceiling"
    assert_selector "[data-combination='R7 W7 B7'][data-thin]"
    assert_text "NOT SETTLED"
    assert_no_text "BELOW BAND"
  end

  test "an exact figure is still shown as one, with nothing it might be out by" do
    Calculation.start(@variation).perform

    visit game_variation_path(@game, @variation)

    assert_text "86.58%"
    assert_text "Exact"
    assert_no_selector "[data-interval]"
    assert_no_selector "[data-coverage]"
  end

  # The run happens in the background, so the page has to gain the coverage without being
  # reloaded. Nothing but a browser can show that the broadcast carries it.
  test "coverage arrives on the page when the run finishes" do
    visit game_variation_path(@game, @variation)
    assert_no_selector "[data-coverage]"

    sample

    assert_selector "[data-coverage]"
    assert_text "R7 W7 B7"
  end

  private
    def sample
      precision = Rtp::Precision.new(points: 0.01, confidence: 95, ceiling: 20_000)

      Calculation.simulate(@variation, precision: precision, seed: 20_260_906).perform
    end
end
