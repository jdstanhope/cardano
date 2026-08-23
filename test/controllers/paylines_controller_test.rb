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
      post apply_set_game_paylines_url(@game), params: { size: 9 }
    end

    assert_redirected_to game_url(@game)
    assert_equal (1..9).to_a, @game.paylines.reload.order(:position).map(&:position)
    assert_equal [ 0, 0, 0, 0, 0 ], @game.paylines.order(:position).first.rows
  end

  test "every applied line is valid for the window" do
    @game.paylines.destroy_all
    post apply_set_game_paylines_url(@game), params: { size: 25 }

    @game.paylines.reload.each { |payline| assert_predicate payline, :valid? }
  end

  test "applying a set replaces what was there rather than adding to it" do
    post apply_set_game_paylines_url(@game), params: { size: 5 }
    post apply_set_game_paylines_url(@game), params: { size: 5 }

    assert_equal 5, @game.paylines.reload.count
  end

  test "a size the window does not offer is refused" do
    assert_no_difference -> { @game.paylines.count } do
      post apply_set_game_paylines_url(@game), params: { size: 7 }
    end

    assert_redirected_to game_url(@game)
  end

  test "a single line can be removed to make a subset" do
    @game.paylines.destroy_all
    post apply_set_game_paylines_url(@game), params: { size: 5 }
    removing = @game.paylines.reload.order(:position).last

    assert_difference -> { @game.paylines.count }, -1 do
      delete game_payline_url(@game, removing)
    end

    assert_redirected_to game_url(@game)
  end

  test "a line can be added to a game that already has paylines" do
    @game.paylines.destroy_all
    post apply_set_game_paylines_url(@game), params: { size: 5 }
    existing = @game.paylines.reload.order(:position).map(&:rows)

    unused = PaylineCatalogue.new(@game).shapes.find { |shape| existing.exclude?(shape) }

    assert_difference -> { @game.paylines.count }, 1 do
      post game_paylines_url(@game), params: { rows: unused }
    end

    assert_equal existing, @game.paylines.reload.order(:position).first(5).map(&:rows),
      "adding must not disturb the lines already there"
    assert_equal unused, @game.paylines.order(:position).last.rows
    assert_equal 6, @game.paylines.order(:position).last.position
  end

  test "a line already in the game cannot be added twice" do
    existing = @game.paylines.first

    assert_no_difference -> { @game.paylines.count } do
      post game_paylines_url(@game), params: { rows: existing.rows }
    end

    follow_redirect!
    assert_select "#alert", /already/i
  end

  test "a shape that does not fit the window is refused" do
    assert_no_difference -> { @game.paylines.count } do
      post game_paylines_url(@game), params: { rows: [ 2, 0, 0, 0, 0 ] }
    end

    follow_redirect!
    assert_select "#alert"
  end

  test "the picker offers only shapes not already in use" do
    @game.paylines.destroy_all
    post apply_set_game_paylines_url(@game), params: { size: 5 }

    get game_url(@game)

    in_use = @game.paylines.reload.map(&:rows)
    assert_select "[data-payline-picker] form" do |forms|
      assert_predicate forms, :any?
      offered = forms.map { |form| form.css("input[name='rows[]']").map { |input| input["value"].to_i } }
      offered.each { |shape| assert_not_includes in_use, shape, "#{shape.inspect} is already in the game" }
    end
  end

  test "another person's game cannot have a payline added" do
    assert_no_difference -> { Payline.count } do
      post game_paylines_url(games(:other_game)), params: { rows: [ 0, 0, 0, 0, 0 ] }
    end

    assert_response :not_found
  end

  test "another person's game cannot have paylines applied or removed" do
    post apply_set_game_paylines_url(games(:other_game)), params: { size: 5 }
    assert_response :not_found

    delete game_payline_url(games(:other_game), paylines(:centre))
    assert_response :not_found
  end

  test "signing in is required" do
    sign_out

    post apply_set_game_paylines_url(@game), params: { size: 5 }
    assert_redirected_to new_session_path
  end
end
