require "test_helper"

class VariationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @game = games(:five_by_three)
    @variation = variations(:ninety_six)
    sign_in_as @game.user
  end

  test "shows a column of stops per reel" do
    get game_variation_url(@game, @variation)

    assert_response :success
    assert_select "[data-controller=reel]", @game.reel_count,
      "one column per reel, whether or not a strip exists yet"
  end

  # One input per stop, in order: the column is the strip.
  test "pre-fills the strips that already exist, one stop per input" do
    strip = reel_strips(:reel_one)

    get game_variation_url(@game, @variation)

    # Scoped to the rows: the cloning template holds a blank row too, which a browser
    # treats as inert but a parser does not.
    inputs = css_select("[data-reel-target=rows] input[name='reels[1][]']").map { |input| input["value"] }
    assert_equal strip.symbols, inputs
  end

  test "a reel with no strip yet still offers somewhere to start" do
    empty = @game.reel_count

    get game_variation_url(@game, @variation)

    assert_select "[data-reel-target=rows] input[name=?]", "reels[#{empty}][]", 1
  end

  test "every stop is labelled for a screen reader" do
    get game_variation_url(@game, @variation)

    assert_select "[data-reel-target=rows] input[aria-label=?]", "Reel 1 stop 1"
    assert_select "[data-reel-target=rows] input[aria-label=?]", "Reel 1 stop 6"
  end

  test "adds a variation and opens it" do
    assert_difference -> { @game.variations.count }, 1 do
      post game_variations_url(@game)
    end

    created = @game.variations.order(:number).last
    assert_redirected_to game_variation_url(@game, created)
    assert_equal 3, created.number, "the fixtures hold 01 and 02, so the next free number is 3"
  end

  test "a stranded game can be given its first variation" do
    @game.variations.destroy_all

    assert_difference -> { @game.variations.count }, 1 do
      post game_variations_url(@game)
    end

    assert_equal 1, @game.variations.reload.first.number
  end

  test "a variation cannot be added to another person's game" do
    assert_no_difference -> { Variation.count } do
      post game_variations_url(games(:other_game))
    end

    assert_response :not_found
  end

  test "another person's variation is not found" do
    get game_variation_url(games(:other_game), @variation)

    assert_response :not_found
  end

  test "signing in is required" do
    sign_out

    get game_variation_url(@game, @variation)
    assert_redirected_to new_session_path
  end

  # Viewing a variation starts a run, and the run is what records a figure.
  test "viewing a complete variation records its figure once" do
    game = SampleGame::RedWhiteAndBlue.build_for(@game.user)
    variation = game.variations.first

    assert_difference -> { variation.rtp_figures.count }, 1 do
      perform_enqueued_jobs { get game_variation_url(game, variation) }
    end
    assert_response :success

    # A second look changes nothing, so it must not start a run or record anything.
    assert_no_difference -> { variation.calculations.count } do
      assert_no_difference -> { variation.rtp_figures.count } do
        perform_enqueued_jobs { get game_variation_url(game, variation) }
      end
    end
  end
end
