require "test_helper"

class VariationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    @variation = variations(:ninety_six)
    sign_in_as @game.user
  end

  test "shows a variation with a text area per reel" do
    get game_variation_url(@game, @variation)

    assert_response :success
    assert_select "textarea[name=?]", "reels[1]"
    assert_select "textarea", @game.reel_count,
      "one text area per reel, whether or not a strip exists yet"
  end

  test "pre-fills the strips that already exist" do
    get game_variation_url(@game, @variation)

    assert_select "textarea[name=?]", "reels[1]", text: /#{reel_strips(:reel_one).symbols.join(" ")}/
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

  # Viewing a variation is what computes its figure, so it is also what records one.
  test "viewing a complete variation records its figure once" do
    game = SampleGame::RedWhiteAndBlue.build_for(@game.user)
    variation = game.variations.first

    assert_difference -> { variation.rtp_figures.count }, 1 do
      get game_variation_url(game, variation)
    end
    assert_response :success

    # A second look changes nothing, so it must not record anything either.
    assert_no_difference -> { variation.rtp_figures.count } do
      get game_variation_url(game, variation)
    end
  end
end
