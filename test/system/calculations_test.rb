require "application_system_test_case"

class CalculationsTest < ApplicationSystemTestCase
  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_through_the_form(users(:one))
  end

  # The whole point of a run: the page arrives without the figure and gains it without
  # being reloaded. Nothing but a browser can show that the broadcast lands.
  test "the figure arrives on the page after the run finishes" do
    visit game_variation_path(@game, @variation)

    assert_text "Working it out"

    Calculation.start(@variation).perform

    assert_text "86.58%"
    assert_no_text "Working it out"
  end

  test "a run can be asked for, and joins the list as queued" do
    Calculation.start(@variation).perform
    visit game_variation_path(@game, @variation)
    assert_selector "[data-calculation]", count: 1

    click_on "Run again"

    assert_selector "[data-calculation]", count: 2
    assert_selector "[data-state='queued']"
    # The figure that is already known stays on the page while the new run happens.
    assert_text "86.58%"
  end
end
