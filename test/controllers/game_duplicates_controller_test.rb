require "test_helper"

class GameDuplicatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    sign_in_as @game.user
  end

  test "duplicating lands you on the copy" do
    assert_difference -> { @game.user.games.count }, 1 do
      post game_duplicate_url(@game)
    end

    copy = @game.user.games.order(:created_at).last
    assert_redirected_to game_url(copy)
    assert_not_equal @game.id, copy.id
    assert_equal "#{@game.name} (copy)", copy.name
  end

  # Without owner scoping this would be a way to read any game in the system by taking
  # a copy of it.
  test "another person's game cannot be duplicated" do
    someone_elses = games(:other_game)
    assert_not_equal someone_elses.user, @game.user

    assert_no_difference -> { Game.count } do
      post game_duplicate_url(someone_elses)
    end

    assert_response :not_found
  end

  test "signing in is required" do
    reset!

    post game_duplicate_url(@game)

    assert_redirected_to new_session_url
  end
end
