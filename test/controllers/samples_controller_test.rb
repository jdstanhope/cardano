require "test_helper"

class SamplesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "copying a sample lands you on a game of your own" do
    assert_difference -> { users(:one).games.count }, 1 do
      post sample_url("red_white_and_blue")
    end

    game = users(:one).games.order(:created_at).last
    assert_redirected_to game_url(game)
    assert_equal "Red White & Blue", game.name
    assert_equal users(:one), game.user
  end

  # The sample is the point of the feature: a game somebody can read rather than
  # describe. A copy that arrives without its paytable teaches nothing.
  test "the copy arrives complete enough to compute its return" do
    post sample_url("red_white_and_blue")

    variation = users(:one).games.order(:created_at).last.variations.first
    assert_predicate variation.rtp, :exact?
    assert_in_delta SampleGame::RedWhiteAndBlue::PUBLISHED_RETURN, variation.rtp.value.to_f, 0.00005
  end

  test "a second copy is named around the first" do
    2.times { post sample_url("red_white_and_blue") }

    assert_equal [ "Red White & Blue", "Red White & Blue 2" ], users(:one).games.order(:created_at).last(2).map(&:name)
  end

  test "an unknown sample is refused rather than raising" do
    assert_no_difference -> { Game.count } do
      post sample_url("not_a_sample")
    end

    assert_redirected_to games_url
  end

  test "signing in is required" do
    reset!

    post sample_url("red_white_and_blue")

    assert_redirected_to new_session_url
  end

  test "the games list offers the sample" do
    get games_url

    assert_response :success
    assert_select "form[action=?]", sample_path("red_white_and_blue")
  end
end
