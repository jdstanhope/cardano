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

  test "another person's variation is not found" do
    get game_variation_url(games(:other_game), @variation)

    assert_response :not_found
  end

  test "signing in is required" do
    sign_out

    get game_variation_url(@game, @variation)
    assert_redirected_to new_session_path
  end
end
