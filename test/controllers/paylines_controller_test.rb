require "test_helper"

class PaylinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    sign_in_as @game.user
  end

  test "the game page offers the sets its window has" do
    get game_url(@game)

    assert_response :success
    assert_select "[data-payline-sets] button", text: /9 lines/
  end

  test "applying a set creates that many paylines, numbered from one" do
    @game.paylines.destroy_all

    assert_difference -> { @game.paylines.count }, 9 do
      post game_paylines_url(@game), params: { size: 9 }
    end

    assert_redirected_to game_url(@game)
    assert_equal (1..9).to_a, @game.paylines.reload.order(:position).map(&:position)
    assert_equal [ 0, 0, 0, 0, 0 ], @game.paylines.order(:position).first.rows
  end

  test "every applied line is valid for the window" do
    @game.paylines.destroy_all
    post game_paylines_url(@game), params: { size: 25 }

    @game.paylines.reload.each { |payline| assert_predicate payline, :valid? }
  end

  test "applying a set replaces what was there rather than adding to it" do
    post game_paylines_url(@game), params: { size: 5 }
    post game_paylines_url(@game), params: { size: 5 }

    assert_equal 5, @game.paylines.reload.count
  end

  test "a size the window does not offer is refused" do
    assert_no_difference -> { @game.paylines.count } do
      post game_paylines_url(@game), params: { size: 7 }
    end

    assert_redirected_to game_url(@game)
  end

  test "a single line can be removed to make a subset" do
    @game.paylines.destroy_all
    post game_paylines_url(@game), params: { size: 5 }
    removing = @game.paylines.reload.order(:position).last

    assert_difference -> { @game.paylines.count }, -1 do
      delete game_payline_url(@game, removing)
    end

    assert_redirected_to game_url(@game)
  end

  test "another person's game cannot have paylines applied or removed" do
    post game_paylines_url(games(:other_game)), params: { size: 5 }
    assert_response :not_found

    delete game_payline_url(games(:other_game), paylines(:centre))
    assert_response :not_found
  end

  test "signing in is required" do
    sign_out

    post game_paylines_url(@game), params: { size: 5 }
    assert_redirected_to new_session_path
  end
end
