require "test_helper"

class CalculationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @game = SampleGame::RedWhiteAndBlue.build_for(users(:one))
    @variation = @game.variations.first
    sign_in_as users(:one)
  end

  test "a run can be asked for" do
    assert_difference -> { @variation.calculations.count }, 1 do
      post game_variation_calculations_url(@game, @variation)
    end

    assert_redirected_to game_variation_url(@game, @variation)
  end

  # Two runs of the same thing answer the same question and cost twice as much.
  test "asking again while one is going does not start a second" do
    post game_variation_calculations_url(@game, @variation)

    assert_no_difference -> { @variation.calculations.count } do
      post game_variation_calculations_url(@game, @variation)
    end

    assert_equal "Already working that out.", flash[:notice]
  end

  test "a partial description is refused with what is missing" do
    empty = @game.variations.create!(number: 2)

    assert_no_difference -> { Calculation.count } do
      post game_variation_calculations_url(@game, empty)
    end

    assert_match(/no reel strips/, flash[:alert])
  end

  test "a run can be stopped" do
    calculation = Calculation.start(@variation)

    delete game_variation_calculation_url(@game, @variation, calculation)

    assert_predicate calculation.reload, :cancelled?
  end

  test "stopping a run that already finished changes nothing" do
    calculation = perform_enqueued_jobs { Calculation.start(@variation) }.reload
    assert_predicate calculation, :done?

    delete game_variation_calculation_url(@game, @variation, calculation)

    assert_predicate calculation.reload, :done?
  end

  test "another person's variation is not found" do
    theirs = users(:two).games.create!(name: "Theirs", reel_count: 3, row_count: 1)

    assert_no_difference -> { Calculation.count } do
      post game_variation_calculations_url(theirs, theirs.variations.first)
    end

    assert_response :not_found
  end

  test "another person's run cannot be stopped" do
    theirs = users(:two).games.create!(name: "Theirs", reel_count: 3, row_count: 1)
    calculation = Calculation.create!(variation: theirs.variations.first, computed_by: "exact",
                                      state: Calculation::QUEUED, fingerprint: "x")

    delete game_variation_calculation_url(@game, @variation, calculation)

    assert_response :not_found
    assert_predicate calculation.reload, :in_flight?
  end

  test "signing in is required" do
    reset!

    post game_variation_calculations_url(@game, @variation)

    assert_redirected_to new_session_url
  end

  # Viewing is what starts a run when there is nothing current, so that the page never
  # blocks on a calculation that takes tens of seconds.
  test "viewing a variation with no figure starts a run" do
    assert_difference -> { @variation.calculations.count }, 1 do
      get game_variation_url(@game, @variation)
    end

    assert_select "[data-calculation]", 1
    assert_select "[data-state=?]", "queued"
    assert_match(/Working it out/, css_select("[data-rtp]").first.text)
  end

  test "viewing again while a run is going does not start another" do
    get game_variation_url(@game, @variation)

    assert_no_difference -> { @variation.calculations.count } do
      get game_variation_url(@game, @variation)
    end
  end

  test "a figure that no longer describes the variation starts a run and is marked" do
    perform_enqueued_jobs { get game_variation_url(@game, @variation) }
    @variation.paytable_entries.find_by(payout: 2400).update!(payout: 4800)

    assert_difference -> { @variation.calculations.count }, 1 do
      get game_variation_url(@game, @variation)
    end

    section = css_select("[data-rtp]").first.text
    assert_match(/out of date/, section)
    # The last figure is still shown: it is the last thing known.
    assert_match(/86\.58%/, section)
  end
end
