require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:five_by_three)
    sign_in_as @game.user
  end

  # The security case. Slice 1 left scoping as a convention because there was no
  # controller; this is where it has to become a constraint.
  test "another person's game is not found, rather than forbidden" do
    someone_elses = games(:other_game)
    assert_not_equal someone_elses.user, @game.user

    get game_url(someone_elses)

    assert_response :not_found,
      "404 rather than 403: a 403 would confirm the record exists"
  end

  test "the dashboard lists only your own games" do
    get games_url

    assert_response :success
    assert_select "body", /#{Regexp.escape(@game.name)}/
    assert_select "body", { text: /#{Regexp.escape(games(:other_game).name)}/, count: 0 },
      "another person's game must not appear"
  end

  test "signing in is required" do
    sign_out

    get games_url
    assert_redirected_to new_session_path

    get game_url(@game)
    assert_redirected_to new_session_path
  end

  test "shows a game with its symbols, paylines, and variations" do
    get game_url(@game)

    assert_response :success
    assert_select "[data-symbols]", /A/
    assert_select "[data-paylines] [data-payline]", @game.paylines.count
    assert_select "[data-variations]", /96/
  end

  test "creates a game and opens it" do
    assert_difference -> { @game.user.games.count }, 1 do
      post games_url, params: { game: { name: "Brand New", reel_count: 5, row_count: 3 } }
    end

    created = Game.find_by(name: "Brand New")
    assert_redirected_to game_url(created)
    assert_equal @game.user, created.user, "a game belongs to whoever created it"
  end

  test "reports why a game could not be created" do
    assert_no_difference -> { Game.count } do
      post games_url, params: { game: { name: "", reel_count: 0, row_count: 3 } }
    end

    assert_response :unprocessable_entity
    assert_select "[data-form-errors]"
  end

  test "a name already used by someone else is still available to you" do
    assert_difference -> { Game.count }, 1 do
      post games_url, params: { game: { name: games(:other_game).name, reel_count: 5, row_count: 3 } }
    end
  end

  test "the empty state invites making a first game" do
    @game.user.games.destroy_all

    get games_url

    assert_response :success
    assert_select "a[href=?]", new_game_path
  end
end
